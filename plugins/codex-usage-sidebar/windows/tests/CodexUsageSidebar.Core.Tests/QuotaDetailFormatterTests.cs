using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Core.Tests;

[TestClass]
public sealed class QuotaDetailFormatterTests
{
    private static readonly DateTimeOffset Now = DateTimeOffset.FromUnixTimeSeconds(1_785_000_000);
    private static readonly TimeZoneInfo ChinaTime = TimeZoneInfo.CreateCustomTimeZone(
        "Fixture UTC+8", TimeSpan.FromHours(8), "Fixture UTC+8", "Fixture UTC+8");

    [TestMethod]
    public void MatchesTheMacSimplifiedChineseInformationModel()
    {
        var content = QuotaDetailFormatter.Format(
            FullSnapshot(), Now, DisplayLanguage.SimplifiedChinese, ChinaTime);

        Assert.AreEqual("Codex 剩余额度", content.Title);
        CollectionAssert.Contains(content.Rows.ToArray(), new QuotaDetailRow("套餐", "Plus"));
        CollectionAssert.Contains(content.Rows.ToArray(), new QuotaDetailRow("额度周期", "7 天"));
        CollectionAssert.Contains(content.Rows.ToArray(), new QuotaDetailRow("下次重置", "8月2日 08:00（7d6h）"));
        CollectionAssert.Contains(content.Rows.ToArray(), new QuotaDetailRow("Credits", "12.50"));
        CollectionAssert.Contains(content.Rows.ToArray(), new QuotaDetailRow("Bank 可用重置", "2 次"));
        CollectionAssert.Contains(content.Rows.ToArray(), new QuotaDetailRow("Bank 1到期时间", "8月1日 04:19（6d2h）"));
    }

    [TestMethod]
    public void MatchesTheMacEnglishAndTraditionalChineseCopy()
    {
        var english = QuotaDetailFormatter.Format(
            FullSnapshot(), Now, DisplayLanguage.English, ChinaTime);
        var traditional = QuotaDetailFormatter.Format(
            FullSnapshot(), Now, DisplayLanguage.TraditionalChinese, ChinaTime);

        Assert.AreEqual("Codex quota", english.Title);
        CollectionAssert.Contains(english.Rows.ToArray(), new QuotaDetailRow("Next reset", "Aug 2, 08:00 (7d6h)"));
        CollectionAssert.Contains(english.Rows.ToArray(), new QuotaDetailRow("Bank resets available", "2 resets"));
        Assert.AreEqual("Codex 剩餘額度", traditional.Title);
        CollectionAssert.Contains(traditional.Rows.ToArray(), new QuotaDetailRow("方案", "Plus"));
        CollectionAssert.Contains(traditional.Rows.ToArray(), new QuotaDetailRow("下次重設", "8月2日 08:00（7d6h）"));
    }

    private static AllowanceSnapshot FullSnapshot() => new(
        24,
        76,
        DateTimeOffset.FromUnixTimeSeconds(1_785_628_824),
        Now.AddSeconds(-20),
        10_080,
        "plus",
        new CreditBalance(true, false, "12.50"),
        new BankResetSummary(2,
        [
            new BankResetCredit("available", null, DateTimeOffset.FromUnixTimeSeconds(1_785_529_171), "Full reset", null),
            new BankResetCredit("available", null, DateTimeOffset.FromUnixTimeSeconds(1_786_557_641), "Full reset", null),
        ]));
}
