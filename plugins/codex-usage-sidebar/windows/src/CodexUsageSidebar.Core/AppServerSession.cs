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
        if (this.pollInterval <= TimeSpan.Zero) throw new ArgumentOutOfRangeException(nameof(pollInterval));
        if (this.responseTimeout <= TimeSpan.Zero) throw new ArgumentOutOfRangeException(nameof(responseTimeout));
    }

    public async Task RunAsync(
        Func<AllowanceSnapshot, ValueTask> snapshotReceived,
        CancellationToken cancellationToken,
        Func<TokenUsageSnapshot, ValueTask>? tokenUsageReceived = null,
        Func<AccountIdentity, ValueTask>? accountReceived = null)
    {
        await using var connection = await connectionFactory.ConnectAsync(cancellationToken).ConfigureAwait(false);
        var initializeRequest = protocol.CreateInitializeRequest();
        var initializeId = ResponseId(initializeRequest)
            ?? throw new InvalidOperationException("Initialize request did not contain a numeric id.");
        await connection.WriteLineAsync(initializeRequest, cancellationToken).ConfigureAwait(false);

        var initialized = false;
        AllowanceSnapshot? latest = null;
        var pending = new Dictionary<int, PendingRequestKind>();
        var rateReadSuperseded = false;
        Task? responseDeadline = Task.Delay(responseTimeout, cancellationToken);
        using var readCancellation = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        var lines = connection.ReadLinesAsync(readCancellation.Token).GetAsyncEnumerator(readCancellation.Token);
        var moveNext = lines.MoveNextAsync().AsTask();
        try
        {
            while (true)
            {
                var rateReadPending = pending.Values.Any(kind => kind == PendingRequestKind.RateLimit);
                if (!initialized || rateReadPending)
                {
                    if (!await WaitForLineOrDeadline(moveNext, responseDeadline, initialized).ConfigureAwait(false)) break;
                }
                else
                {
                    var poll = Task.Delay(pollInterval, cancellationToken);
                    if (await Task.WhenAny(moveNext, poll).ConfigureAwait(false) == poll)
                    {
                        await poll.ConfigureAwait(false);
                        await SendRateRefreshAsync(connection, pending, cancellationToken).ConfigureAwait(false);
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
                    await SendInitialReadsAsync(connection, pending, cancellationToken).ConfigureAwait(false);
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
                        if (pending.Values.Any(kind => kind == PendingRequestKind.RateLimit))
                        {
                            rateReadSuperseded = true;
                        }
                        else
                        {
                            await SendRateRefreshAsync(connection, pending, cancellationToken).ConfigureAwait(false);
                            responseDeadline = Task.Delay(responseTimeout, cancellationToken);
                        }
                    }
                    continue;
                }

                var responseId = ResponseId(line);
                if (responseId is null || !pending.Remove(responseId.Value, out var kind)) continue;
                switch (kind)
                {
                    case PendingRequestKind.RateLimit:
                        if (!rateReadSuperseded)
                        {
                            var response = protocol.DecodeSnapshot(line, now());
                            if (response is not null)
                            {
                                latest = response.MergeSupplementary(latest);
                                await snapshotReceived(latest).ConfigureAwait(false);
                            }
                        }
                        if (rateReadSuperseded)
                        {
                            rateReadSuperseded = false;
                            await SendRateRefreshAsync(connection, pending, cancellationToken).ConfigureAwait(false);
                        }
                        break;
                    case PendingRequestKind.TokenUsage:
                        if (tokenUsageReceived is not null && protocol.DecodeTokenUsage(line, now()) is { } usage)
                            await tokenUsageReceived(usage).ConfigureAwait(false);
                        break;
                    case PendingRequestKind.Account:
                        if (accountReceived is not null && protocol.DecodeAccount(line) is { } account)
                            await accountReceived(account).ConfigureAwait(false);
                        break;
                }
                responseDeadline = pending.Values.Any(kind => kind == PendingRequestKind.RateLimit)
                    ? Task.Delay(responseTimeout, cancellationToken)
                    : null;
            }
        }
        finally
        {
            readCancellation.Cancel();
            try { await moveNext.ConfigureAwait(false); } catch (OperationCanceledException) { }
            await lines.DisposeAsync().ConfigureAwait(false);
        }
    }

    private async ValueTask SendInitialReadsAsync(
        IJsonLineConnection connection,
        IDictionary<int, PendingRequestKind> pending,
        CancellationToken cancellationToken)
    {
        await SendRateReadAsync(connection, pending, cancellationToken).ConfigureAwait(false);
        await SendRequestAsync(connection, pending, protocol.CreateTokenUsageRead(), PendingRequestKind.TokenUsage, cancellationToken).ConfigureAwait(false);
        await SendRequestAsync(connection, pending, protocol.CreateAccountRead(), PendingRequestKind.Account, cancellationToken).ConfigureAwait(false);
    }

    private async ValueTask<int> SendRateReadAsync(
        IJsonLineConnection connection,
        IDictionary<int, PendingRequestKind> pending,
        CancellationToken cancellationToken) =>
        await SendRequestAsync(connection, pending, protocol.CreateRateLimitRead(), PendingRequestKind.RateLimit, cancellationToken).ConfigureAwait(false);

    private async ValueTask SendRateRefreshAsync(
        IJsonLineConnection connection,
        IDictionary<int, PendingRequestKind> pending,
        CancellationToken cancellationToken)
    {
        await SendRateReadAsync(connection, pending, cancellationToken).ConfigureAwait(false);
        if (!pending.Values.Any(kind => kind == PendingRequestKind.TokenUsage))
        {
            await SendRequestAsync(
                connection,
                pending,
                protocol.CreateTokenUsageRead(),
                PendingRequestKind.TokenUsage,
                cancellationToken).ConfigureAwait(false);
        }
    }

    private static async ValueTask<int> SendRequestAsync(
        IJsonLineConnection connection,
        IDictionary<int, PendingRequestKind> pending,
        JsonRpcRequest request,
        PendingRequestKind kind,
        CancellationToken cancellationToken)
    {
        pending[request.Id] = kind;
        await connection.WriteLineAsync(request.Json, cancellationToken).ConfigureAwait(false);
        return request.Id;
    }

    private static async Task<bool> WaitForLineOrDeadline(Task<bool> moveNext, Task? deadline, bool initialized)
    {
        if (deadline is null) return await moveNext.ConfigureAwait(false);
        if (await Task.WhenAny(moveNext, deadline).ConfigureAwait(false) == deadline)
        {
            await deadline.ConfigureAwait(false);
            throw new TimeoutException(initialized
                ? "The Codex app-server did not answer before the response deadline."
                : "The Codex app-server did not initialize before the response deadline.");
        }
        return await moveNext.ConfigureAwait(false);
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
        catch (JsonException) { return false; }
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
        catch (JsonException) { return false; }
    }

    private static int? ResponseId(string line)
    {
        try
        {
            using var document = JsonDocument.Parse(line);
            return document.RootElement.TryGetProperty("id", out var id)
                && id.ValueKind == JsonValueKind.Number
                && id.TryGetInt32(out var value) ? value : null;
        }
        catch (JsonException) { return null; }
    }

    private enum PendingRequestKind { RateLimit, TokenUsage, Account }
}
