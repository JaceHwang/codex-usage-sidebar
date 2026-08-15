using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Core.Tests;

[TestClass]
public sealed class RateLimitDecoderTests
{
    [TestMethod]
    public void DecodesSharedReadResponseIncludingCreditsAndBank()
    {
        var json = File.ReadAllText(ContractPath("rate-limits", "read-response.json"));

        var snapshot = RateLimitDecoder.DecodeResponse(json, DateTimeOffset.FromUnixTimeSeconds(1_785_000_000));

        Assert.AreEqual(24d, snapshot.UsedPercent);
        Assert.AreEqual(76, snapshot.RemainingPercent);
        Assert.AreEqual(DateTimeOffset.FromUnixTimeSeconds(1_785_628_824), snapshot.ResetsAt);
        Assert.AreEqual(10_080, snapshot.WindowDurationMinutes);
        Assert.AreEqual("plus", snapshot.PlanType);
        Assert.AreEqual("12.50", snapshot.Credits?.Balance);
        Assert.AreEqual(2, snapshot.Bank?.AvailableCount);
        Assert.AreEqual(2, snapshot.Bank?.Credits?.Count);
    }

    [TestMethod]
    public void DecodesSharedNotificationAndRejectsUnrelatedMethod()
    {
        var json = File.ReadAllText(ContractPath("rate-limits", "updated-notification.json"));
        var snapshot = RateLimitDecoder.DecodeNotification(json, DateTimeOffset.UnixEpoch);
        Assert.AreEqual(69, snapshot.RemainingPercent);
        Assert.ThrowsException<RateLimitDecodingException>(() =>
            RateLimitDecoder.DecodeNotification("{\"method\":\"other\",\"params\":{}}", DateTimeOffset.UnixEpoch));
    }

    private static string ContractPath(params string[] components) =>
        components.Prepend("contracts").Prepend(AppContext.BaseDirectory).Aggregate(Path.Combine);
}
