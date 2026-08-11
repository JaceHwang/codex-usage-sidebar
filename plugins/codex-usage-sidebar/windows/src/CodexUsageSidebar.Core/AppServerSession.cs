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
        await foreach (var line in connection.ReadLinesAsync(cancellationToken).ConfigureAwait(false))
        {
            if (!initialized && IsSuccessfulResponse(line, 1))
            {
                initialized = true;
                await connection.WriteLineAsync(protocol.CreateInitializedNotification(), cancellationToken).ConfigureAwait(false);
                await connection.WriteLineAsync(protocol.CreateRateLimitReadRequest(), cancellationToken).ConfigureAwait(false);
                continue;
            }

            var snapshot = protocol.DecodeSnapshot(line, now());
            if (snapshot is null)
            {
                continue;
            }

            var isNotification = IsRateLimitNotification(line);
            latest = snapshot.MergeSupplementary(latest);
            await snapshotReceived(latest).ConfigureAwait(false);
            if (isNotification)
            {
                await connection.WriteLineAsync(protocol.CreateRateLimitReadRequest(), cancellationToken).ConfigureAwait(false);
            }
        }
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
}
