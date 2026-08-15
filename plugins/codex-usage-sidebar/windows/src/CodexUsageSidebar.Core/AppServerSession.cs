using System.Text.Json;

namespace CodexUsageSidebar.Core;

public interface IJsonLineConnection : IAsyncDisposable
{
    ValueTask WriteLineAsync(string line, CancellationToken cancellationToken);
    IAsyncEnumerable<string> ReadLinesAsync(CancellationToken cancellationToken);
}

public interface IJsonLineConnectionFactory
{
    ValueTask<IJsonLineConnection> ConnectAsync(CancellationToken cancellationToken);
}

public sealed class AppServerSession
{
    private readonly IJsonLineConnectionFactory connectionFactory;
    private readonly AppServerProtocol protocol;
    private readonly Func<DateTimeOffset> now;
    private readonly TimeSpan pollInterval;
    private readonly TimeSpan responseTimeout;

    public AppServerSession(
        IJsonLineConnectionFactory connectionFactory,
        AppServerProtocol protocol,
        Func<DateTimeOffset> now,
        TimeSpan? pollInterval = null,
        TimeSpan? responseTimeout = null)
    {
        this.connectionFactory = connectionFactory;
        this.protocol = protocol;
        this.now = now;
        this.pollInterval = pollInterval ?? TimeSpan.FromSeconds(5);
        this.responseTimeout = responseTimeout ?? TimeSpan.FromSeconds(15);
        if (this.pollInterval <= TimeSpan.Zero)
        {
            throw new ArgumentOutOfRangeException(nameof(pollInterval));
        }
        if (this.responseTimeout <= TimeSpan.Zero)
        {
            throw new ArgumentOutOfRangeException(nameof(responseTimeout));
        }
    }

    public async Task RunAsync(
        Func<AllowanceSnapshot, ValueTask> snapshotReceived,
        CancellationToken cancellationToken)
    {
        await using var connection = await connectionFactory.ConnectAsync(cancellationToken).ConfigureAwait(false);
        var initializeRequest = protocol.CreateInitializeRequest();
        var initializeId = ResponseId(initializeRequest)
            ?? throw new InvalidOperationException("Initialize request did not contain a numeric id.");
        await connection.WriteLineAsync(initializeRequest, cancellationToken).ConfigureAwait(false);

        var initialized = false;
        AllowanceSnapshot? latest = null;
        int? pendingReadId = null;
        var pendingReadWasSuperseded = false;
        Task? responseDeadline = Task.Delay(responseTimeout, cancellationToken);
        using var readCancellation = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        var lines = connection.ReadLinesAsync(readCancellation.Token)
            .GetAsyncEnumerator(readCancellation.Token);
        var moveNext = lines.MoveNextAsync().AsTask();
        try
        {
            while (true)
            {
                if (!initialized || pendingReadId is not null)
                {
                    if (responseDeadline is null)
                    {
                        throw new InvalidOperationException("A pending app-server request has no deadline.");
                    }
                    if (await Task.WhenAny(moveNext, responseDeadline).ConfigureAwait(false) == responseDeadline)
                    {
                        await responseDeadline.ConfigureAwait(false);
                        throw new TimeoutException("The Codex app-server did not answer before the response deadline.");
                    }
                }
                else
                {
                    var poll = Task.Delay(pollInterval, cancellationToken);
                    if (await Task.WhenAny(moveNext, poll).ConfigureAwait(false) == poll)
                    {
                        await poll.ConfigureAwait(false);
                        pendingReadId = await SendReadAsync(connection, cancellationToken).ConfigureAwait(false);
                        responseDeadline = Task.Delay(responseTimeout, cancellationToken);
                        continue;
                    }
                }

                if (!await moveNext.ConfigureAwait(false)) break;
                var line = lines.Current;
                moveNext = lines.MoveNextAsync().AsTask();

                if (!initialized && IsSuccessfulResponse(line, initializeId))
                {
                    initialized = true;
                    await connection.WriteLineAsync(protocol.CreateInitializedNotification(), cancellationToken).ConfigureAwait(false);
                    pendingReadId = await SendReadAsync(connection, cancellationToken).ConfigureAwait(false);
                    responseDeadline = Task.Delay(responseTimeout, cancellationToken);
                    continue;
                }

                if (IsRateLimitNotification(line))
                {
                    var notification = protocol.DecodeSnapshot(line, now());
                    if (notification is not null)
                    {
                        latest = notification.MergeSupplementary(latest);
                        await snapshotReceived(latest).ConfigureAwait(false);
                        if (pendingReadId is null)
                        {
                            pendingReadId = await SendReadAsync(connection, cancellationToken).ConfigureAwait(false);
                            responseDeadline = Task.Delay(responseTimeout, cancellationToken);
                        }
                        else
                        {
                            pendingReadWasSuperseded = true;
                        }
                    }
                    continue;
                }

                var responseId = ResponseId(line);
                if (pendingReadId is null || responseId != pendingReadId)
                {
                    continue;
                }
                pendingReadId = null;
                responseDeadline = null;
                if (!pendingReadWasSuperseded)
                {
                    var response = protocol.DecodeSnapshot(line, now());
                    if (response is not null)
                    {
                        latest = response.MergeSupplementary(latest);
                        await snapshotReceived(latest).ConfigureAwait(false);
                    }
                }
                if (pendingReadWasSuperseded)
                {
                    pendingReadWasSuperseded = false;
                    pendingReadId = await SendReadAsync(connection, cancellationToken).ConfigureAwait(false);
                    responseDeadline = Task.Delay(responseTimeout, cancellationToken);
                }
            }
        }
        finally
        {
            readCancellation.Cancel();
            try
            {
                await moveNext.ConfigureAwait(false);
            }
            catch (OperationCanceledException)
            {
            }
            await lines.DisposeAsync().ConfigureAwait(false);
        }
    }

    private async ValueTask<int> SendReadAsync(
        IJsonLineConnection connection,
        CancellationToken cancellationToken)
    {
        var request = protocol.CreateRateLimitRead();
        await connection.WriteLineAsync(request.Json, cancellationToken).ConfigureAwait(false);
        return request.Id;
    }

    private static bool IsSuccessfulResponse(string line, int id)
    {
        try
        {
            using var document = JsonDocument.Parse(line);
            var root = document.RootElement;
            return root.TryGetProperty("id", out var responseId)
                && responseId.ValueKind == JsonValueKind.Number
                && responseId.TryGetInt32(out var value)
                && value == id
                && root.TryGetProperty("result", out _);
        }
        catch (JsonException)
        {
            return false;
        }
    }

    private static bool IsRateLimitNotification(string line)
    {
        try
        {
            using var document = JsonDocument.Parse(line);
            return document.RootElement.TryGetProperty("method", out var method)
                && method.ValueKind == JsonValueKind.String
                && method.GetString() == "account/rateLimits/updated";
        }
        catch (JsonException)
        {
            return false;
        }
    }

    private static int? ResponseId(string line)
    {
        try
        {
            using var document = JsonDocument.Parse(line);
            return document.RootElement.TryGetProperty("id", out var id)
                && id.ValueKind == JsonValueKind.Number
                && id.TryGetInt32(out var value)
                    ? value
                    : null;
        }
        catch (JsonException)
        {
            return null;
        }
    }
}
