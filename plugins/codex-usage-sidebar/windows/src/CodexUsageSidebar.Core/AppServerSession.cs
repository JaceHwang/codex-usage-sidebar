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

    public AppServerSession(
        IJsonLineConnectionFactory connectionFactory,
        AppServerProtocol protocol,
        Func<DateTimeOffset> now)
    {
        this.connectionFactory = connectionFactory;
        this.protocol = protocol;
        this.now = now;
    }

    public async Task RunAsync(
        Func<AllowanceSnapshot, ValueTask> snapshotReceived,
        CancellationToken cancellationToken)
    {
        await using var connection = await connectionFactory.ConnectAsync(cancellationToken).ConfigureAwait(false);
        await connection.WriteLineAsync(protocol.CreateInitializeRequest(), cancellationToken).ConfigureAwait(false);

        var initialized = false;
        AllowanceSnapshot? latest = null;
        int? pendingReadId = null;
        var pendingReadWasSuperseded = false;
        await foreach (var line in connection.ReadLinesAsync(cancellationToken).ConfigureAwait(false))
        {
            if (!initialized && IsSuccessfulResponse(line, 1))
            {
                initialized = true;
                await connection.WriteLineAsync(protocol.CreateInitializedNotification(), cancellationToken).ConfigureAwait(false);
                pendingReadId = await SendReadAsync(connection, cancellationToken).ConfigureAwait(false);
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
            }
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
