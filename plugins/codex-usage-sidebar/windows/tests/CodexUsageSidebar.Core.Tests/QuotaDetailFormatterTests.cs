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

    [TestMethod]
    public void FormatsTokenUsageAccountAndVersionForTheWindowsCard()
    {
        var usage = new TokenUsageSnapshot(
            Now,
            [
                new TokenUsageDay(new DateOnly(2026, 7, 31), 280_000),
                new TokenUsageDay(new DateOnly(2026, 8, 1), 320_000),
            ],
            new TokenUsageSummary(1_240_000, 420_000, null, null, null),
            TokenUsageAvailability.Available);
        var account = new AccountIdentity("Jace", "jace@example.com", null);

        var content = QuotaDetailFormatter.Format(
            FullSnapshot(), Now, DisplayLanguage.SimplifiedChinese, ChinaTime, usage, account, "0.3.3");

        Assert.AreEqual("0.3.3", content.Version);
        Assert.AreEqual(account, content.Account);
        Assert.AreEqual("Token 用量", content.TokenUsage?.Title);
        Assert.AreEqual("账户", content.AccountLabel);
        Assert.AreEqual(TokenUsageAvailability.Available, content.TokenUsage?.Availability);
        Assert.AreEqual(7, content.TokenUsage?.Days.Count);
        Assert.AreEqual(600_000, content.TokenUsage?.CurrentPeriodTotal);
        Assert.AreEqual("本周期总计 600K tokens", content.TokenUsage?.TotalLabel);
    }

    [TestMethod]
    public void PreservesTheCompactIndicatorDateSeparatorWhitespace()
    {
        var compact = QuotaDetailFormatter.FormatCompact(
            FullSnapshot(),
            DisplayLanguage.SimplifiedChinese,
            ChinaTime);

        Assert.AreEqual("76% · 8月2日 08:00", compact);
    }

    [TestMethod]
    public void FormatsPrimaryAndWeeklyQuotaWindowsAndIndicatorSummary()
    {
        var content = QuotaDetailFormatter.Format(
            DualSnapshot(), Now, DisplayLanguage.SimplifiedChinese, ChinaTime);

        Assert.AreEqual(2, content.QuotaWindows?.Count);
        Assert.AreEqual("5 小时", content.QuotaWindows?[0].Label);
        Assert.AreEqual(85, content.QuotaWindows?[0].RemainingPercent);
        Assert.AreEqual("7 天", content.QuotaWindows?[1].Label);
        Assert.AreEqual(98, content.QuotaWindows?[1].RemainingPercent);
        CollectionAssert.Contains(
            content.Rows.ToArray(),
            new QuotaDetailRow("额度周期（7天）", "7 天"));
        CollectionAssert.Contains(
            content.Rows.ToArray(),
            new QuotaDetailRow("下次重置（7天）", "9月1日 08:00（37d6h）"));

        var summary = QuotaDetailFormatter.FormatIndicatorSummary(
            DualSnapshot(), DisplayLanguage.SimplifiedChinese, ChinaTime);
        Assert.AreEqual("5 小时 85% · 8月26日 14:55", summary.Primary);
        Assert.AreEqual("7 天 98% · 9月1日 08:00", summary.Secondary);
    }

    [TestMethod]
    public void KeepsTheCardAvailableWhenTokenUsageIsUnsupported()
    {
        var usage = new TokenUsageSnapshot(
            Now,
            Array.Empty<TokenUsageDay>(),
            null,
            TokenUsageAvailability.Unsupported);

        var content = QuotaDetailFormatter.Format(
            FullSnapshot(), Now, DisplayLanguage.English, ChinaTime, usage, null, "0.3.3");

        Assert.AreEqual(76, content.RemainingPercent);
        Assert.AreEqual(TokenUsageAvailability.Unsupported, content.TokenUsage?.Availability);
        Assert.AreEqual(7, content.TokenUsage?.Days.Count);
        Assert.AreEqual("Token usage unavailable", content.TokenUsage?.UnavailableLabel);
        Assert.AreEqual("Account", content.AccountLabel);
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

    private static AllowanceSnapshot DualSnapshot() => new(
        15,
        85,
        DateTimeOffset.FromUnixTimeSeconds(1_787_727_330),
        Now.AddSeconds(-20),
        300,
        "plus",
        null,
        null,
        new QuotaWindowSnapshot(
            2,
            98,
            DateTimeOffset.FromUnixTimeSeconds(1_788_220_800),
            10_080));
}
