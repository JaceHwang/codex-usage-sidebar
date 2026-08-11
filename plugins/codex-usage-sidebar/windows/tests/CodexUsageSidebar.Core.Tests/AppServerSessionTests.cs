using System.Runtime.CompilerServices;
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
            new[] { "initialize", "initialized", "account/rateLimits/read", "account/rateLimits/read" },
            connection.WrittenMethods.ToArray());
        CollectionAssert.AreEqual(new[] { 76, 69 }, snapshots.Select(x => x.RemainingPercent).ToArray());
        Assert.AreEqual(2, snapshots[1].Bank?.AvailableCount);
    }

    private static string ContractPath(string file) =>
        Path.Combine(AppContext.BaseDirectory, "contracts", "rate-limits", file);

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
}
