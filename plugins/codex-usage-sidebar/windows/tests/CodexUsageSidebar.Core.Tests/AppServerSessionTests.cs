using System.Runtime.CompilerServices;
using System.Threading.Channels;
using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Core.Tests;

[TestClass]
public sealed class AppServerSessionTests
{
    [TestMethod]
    public async Task InitializesReadsStreamsAndPreservesSupplementaryBankData()
    {
        var connection = new ReplayConnection(new[]
        {
            "{\"id\":1,\"result\":{}}",
            File.ReadAllText(ContractPath("read-response.json")),
            File.ReadAllText(ContractPath("updated-notification.json")),
        });
        var snapshots = new List<AllowanceSnapshot>();
        var session = new AppServerSession(
            new StubConnectionFactory(connection),
            new AppServerProtocol("test", "1"),
            () => DateTimeOffset.UnixEpoch);

        await session.RunAsync(snapshot =>
        {
            snapshots.Add(snapshot);
            return ValueTask.CompletedTask;
        }, CancellationToken.None);

        CollectionAssert.AreEqual(
            new[] { "initialize", "initialized", "account/rateLimits/read", "account/usage/read", "account/read", "account/rateLimits/read" },
            connection.WrittenMethods.ToArray());
        CollectionAssert.AreEqual(new[] { 76, 69 }, snapshots.Select(x => x.RemainingPercent).ToArray());
        Assert.AreEqual(2, snapshots[1].Bank?.AvailableCount);
    }

    [TestMethod]
    public async Task NotificationDuringPendingReadNeverRevertsAndCoalescesFollowUp()
    {
        var oldResponse = File.ReadAllText(ContractPath("read-response.json"));
        var notification = File.ReadAllText(ContractPath("updated-notification.json"));
        var freshResponse = oldResponse.Replace("\"usedPercent\": 24", "\"usedPercent\": 31", StringComparison.Ordinal);
        var connection = new ReplayConnection(new[]
        {
            "{\"id\":1,\"result\":{}}",
            notification,
            oldResponse,
            freshResponse.Replace("\"id\": 2", "\"id\": 5", StringComparison.Ordinal),
        });
        var snapshots = new List<AllowanceSnapshot>();
        var session = new AppServerSession(
            new StubConnectionFactory(connection),
            new AppServerProtocol("test", "1"),
            () => DateTimeOffset.UnixEpoch);

        await session.RunAsync(snapshot =>
        {
            snapshots.Add(snapshot);
            return ValueTask.CompletedTask;
        }, CancellationToken.None);

        CollectionAssert.AreEqual(new[] { 69, 69 }, snapshots.Select(x => x.RemainingPercent).ToArray());
        CollectionAssert.AreEqual(
            new[] { "initialize", "initialized", "account/rateLimits/read", "account/usage/read", "account/read", "account/rateLimits/read" },
            connection.WrittenMethods.ToArray());
        Assert.AreEqual(2, snapshots[^1].Bank?.AvailableCount);
    }

    [TestMethod]
    public async Task PollsAgainOnAnIdleConnectedSession()
    {
        var connection = new IdleConnection([
            "{\"id\":1,\"result\":{}}",
            File.ReadAllText(ContractPath("read-response.json")),
        ]);
        var session = new AppServerSession(
            new StubConnectionFactory(connection),
            new AppServerProtocol("test", "1"),
            () => DateTimeOffset.UnixEpoch,
            TimeSpan.FromMilliseconds(20));
        using var cancellation = new CancellationTokenSource(TimeSpan.FromSeconds(2));

        var run = session.RunAsync(_ => ValueTask.CompletedTask, cancellation.Token);
        await connection.WaitForWritesAsync(5, cancellation.Token);
        cancellation.Cancel();
        await Assert.ThrowsExceptionAsync<TaskCanceledException>(async () => await run);

        CollectionAssert.AreEqual(
            new[] { "initialize", "initialized", "account/rateLimits/read", "account/usage/read", "account/read" },
            connection.WrittenMethods.ToArray());
    }

    [TestMethod]
    public async Task MissingReadResponseTimesOutSoTheRuntimeCanReconnect()
    {
        var connection = new IdleConnection(["{\"id\":1,\"result\":{}}"]);
        var session = new AppServerSession(
            new StubConnectionFactory(connection),
            new AppServerProtocol("test", "1"),
            () => DateTimeOffset.UnixEpoch,
            TimeSpan.FromSeconds(5),
            TimeSpan.FromMilliseconds(25));

        await Assert.ThrowsExceptionAsync<TimeoutException>(async () =>
            await session.RunAsync(_ => ValueTask.CompletedTask, CancellationToken.None));

        CollectionAssert.AreEqual(
            new[] { "initialize", "initialized", "account/rateLimits/read", "account/usage/read", "account/read" },
            connection.WrittenMethods.ToArray());
    }

    [TestMethod]
    public async Task StreamsTokenUsageAndAccountIdentityAlongsideAllowance()
    {
        var connection = new ReplayConnection(new[]
        {
            "{\"id\":1,\"result\":{}}",
            File.ReadAllText(ContractPath("read-response.json")),
            File.ReadAllText(ContractPathUnder("usage", "read-response.json")),
            File.ReadAllText(ContractPathUnder("account", "read-response.json")),
        });
        TokenUsageSnapshot? tokenUsage = null;
        AccountIdentity? account = null;
        var session = new AppServerSession(
            new StubConnectionFactory(connection),
            new AppServerProtocol("test", "0.3.2"),
            () => DateTimeOffset.UnixEpoch);

        await session.RunAsync(
            _ => ValueTask.CompletedTask,
            CancellationToken.None,
            usage =>
            {
                tokenUsage = usage;
                return ValueTask.CompletedTask;
            },
            identity =>
            {
                account = identity;
                return ValueTask.CompletedTask;
            });

        CollectionAssert.AreEqual(
            new[]
            {
                "initialize",
                "initialized",
                "account/rateLimits/read",
                "account/usage/read",
                "account/read",
            },
            connection.WrittenMethods.ToArray());
        Assert.AreEqual(2, tokenUsage?.DailyBuckets.Count);
        Assert.AreEqual("Jace", account?.PreferredName);
    }

    private static string ContractPath(params string[] parts) =>
        Path.Combine(new[] { AppContext.BaseDirectory, "contracts", "rate-limits" }.Concat(parts).ToArray());

    private static string ContractPathUnder(string folder, string file) =>
        Path.Combine(AppContext.BaseDirectory, "contracts", folder, file);

    private sealed class StubConnectionFactory(IJsonLineConnection connection) : IJsonLineConnectionFactory
    {
        public ValueTask<IJsonLineConnection> ConnectAsync(CancellationToken cancellationToken) =>
            ValueTask.FromResult(connection);
    }

    private sealed class ReplayConnection(IReadOnlyList<string> lines) : IJsonLineConnection
    {
        public List<string> WrittenMethods { get; } = new();

        public ValueTask WriteLineAsync(string line, CancellationToken cancellationToken)
        {
            using var document = System.Text.Json.JsonDocument.Parse(line);
            WrittenMethods.Add(document.RootElement.GetProperty("method").GetString()!);
            return ValueTask.CompletedTask;
        }

        public async IAsyncEnumerable<string> ReadLinesAsync(
            [EnumeratorCancellation] CancellationToken cancellationToken)
        {
            foreach (var line in lines)
            {
                cancellationToken.ThrowIfCancellationRequested();
                yield return line;
                await Task.Yield();
            }
        }

        public ValueTask DisposeAsync() => ValueTask.CompletedTask;
    }

    private sealed class IdleConnection(IReadOnlyList<string> initialLines) : IJsonLineConnection
    {
        private readonly Channel<bool> writes = Channel.CreateUnbounded<bool>();
        public List<string> WrittenMethods { get; } = new();

        public ValueTask WriteLineAsync(string line, CancellationToken cancellationToken)
        {
            using var document = System.Text.Json.JsonDocument.Parse(line);
            lock (WrittenMethods)
            {
                WrittenMethods.Add(document.RootElement.GetProperty("method").GetString()!);
            }
            writes.Writer.TryWrite(true);
            return ValueTask.CompletedTask;
        }

        public async Task WaitForWritesAsync(int count, CancellationToken cancellationToken)
        {
            while (true)
            {
                lock (WrittenMethods)
                {
                    if (WrittenMethods.Count >= count) return;
                }
                await writes.Reader.ReadAsync(cancellationToken);
            }
        }

        public async IAsyncEnumerable<string> ReadLinesAsync(
            [EnumeratorCancellation] CancellationToken cancellationToken)
        {
            foreach (var line in initialLines) yield return line;
            await Task.Delay(Timeout.InfiniteTimeSpan, cancellationToken);
        }

        public ValueTask DisposeAsync() => ValueTask.CompletedTask;
    }
}
