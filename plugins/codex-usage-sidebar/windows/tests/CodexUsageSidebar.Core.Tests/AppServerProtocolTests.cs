using System.Text.Json;
using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Core.Tests;

[TestClass]
public sealed class AppServerProtocolTests
{
    [TestMethod]
    public void BuildsInitializeInitializedAndRateLimitReadMessagesWithIncreasingIds()
    {
        var protocol = new AppServerProtocol("codex_usage_sidebar_windows", "0.3.1");

        using var initialize = JsonDocument.Parse(protocol.CreateInitializeRequest());
        using var initialized = JsonDocument.Parse(protocol.CreateInitializedNotification());
        using var read = JsonDocument.Parse(protocol.CreateRateLimitReadRequest());

        Assert.AreEqual(1, initialize.RootElement.GetProperty("id").GetInt32());
        Assert.AreEqual("initialize", initialize.RootElement.GetProperty("method").GetString());
        Assert.AreEqual("codex_usage_sidebar_windows", initialize.RootElement.GetProperty("params").GetProperty("clientInfo").GetProperty("name").GetString());
        Assert.AreEqual("initialized", initialized.RootElement.GetProperty("method").GetString());
        Assert.AreEqual(2, read.RootElement.GetProperty("id").GetInt32());
        Assert.AreEqual("account/rateLimits/read", read.RootElement.GetProperty("method").GetString());
    }

    [TestMethod]
    public void BuildsUsageAndAccountRequestsAfterRateLimitRequest()
    {
        var protocol = new AppServerProtocol("test", "0.3.1");

        using var usage = JsonDocument.Parse(protocol.CreateTokenUsageRead().Json);
        using var account = JsonDocument.Parse(protocol.CreateAccountRead().Json);

        Assert.AreEqual("account/usage/read", usage.RootElement.GetProperty("method").GetString());
        Assert.AreEqual("account/read", account.RootElement.GetProperty("method").GetString());
        Assert.AreNotEqual(
            usage.RootElement.GetProperty("id").GetInt32(),
            account.RootElement.GetProperty("id").GetInt32());
    }

    [TestMethod]
    public void RoutesBothReadResponsesAndUpdateNotifications()
    {
        var protocol = new AppServerProtocol("test", "1");
        var response = File.ReadAllText(ContractPath("read-response.json"));
        var notification = File.ReadAllText(ContractPath("updated-notification.json"));

        Assert.AreEqual(76, protocol.DecodeSnapshot(response, DateTimeOffset.UnixEpoch)?.RemainingPercent);
        Assert.AreEqual(69, protocol.DecodeSnapshot(notification, DateTimeOffset.UnixEpoch)?.RemainingPercent);
        Assert.IsNull(protocol.DecodeSnapshot("{\"id\":1,\"result\":{}}", DateTimeOffset.UnixEpoch));
    }

    private static string ContractPath(string file) =>
        Path.Combine(AppContext.BaseDirectory, "contracts", "rate-limits", file);
}
