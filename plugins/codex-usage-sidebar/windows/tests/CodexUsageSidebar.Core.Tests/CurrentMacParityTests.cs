using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Core.Tests;

[TestClass]
public sealed class CurrentMacParityTests
{
    [TestMethod]
    public void DetailViewportDefaultsToEightRowsAndClampsBetweenTwoRowsAndTheScreen()
    {
        Assert.AreEqual(32d, QuotaDetailViewportPolicy.RowHeight);
        Assert.AreEqual(256d, QuotaDetailViewportPolicy.DefaultRowViewportHeight);
        Assert.AreEqual(64d, QuotaDetailViewportPolicy.MinimumRowViewportHeight);
        Assert.AreEqual(720d, QuotaDetailViewportPolicy.MaximumPanelHeight);
        Assert.AreEqual(256d, QuotaDetailViewportPolicy.ResolveRowViewportHeight(256, 720, 360));
        Assert.AreEqual(64d, QuotaDetailViewportPolicy.ResolveRowViewportHeight(20, 720, 360));
        Assert.AreEqual(140d, QuotaDetailViewportPolicy.ResolveRowViewportHeight(500, 500, 360));
        Assert.AreEqual("调整高度", QuotaDetailViewportPolicy.ResizeHint(DisplayLanguage.SimplifiedChinese));
        Assert.AreEqual("調整高度", QuotaDetailViewportPolicy.ResizeHint(DisplayLanguage.TraditionalChinese));
        Assert.AreEqual("Adjust height", QuotaDetailViewportPolicy.ResizeHint(DisplayLanguage.English));
        Assert.IsTrue(QuotaDetailViewportPolicy.ShouldKeepDetailVisible(
            isResizing: true,
            DetailInteractionState.Initial));
        Assert.IsFalse(QuotaDetailViewportPolicy.ShouldKeepDetailVisible(
            isResizing: false,
            DetailInteractionState.Initial));
    }

    [TestMethod]
    public void IndicatorExposesIndependentColumnsForBothQuotaWindows()
    {
        var rows = QuotaDetailFormatter.FormatIndicatorRows(Snapshot, DisplayLanguage.SimplifiedChinese, TimeZoneInfo.Utc);
        Assert.AreEqual(2, rows.Count);
        Assert.AreEqual("5 小时", rows[0].Label);
        Assert.AreEqual("76%", rows[0].Percentage);
        Assert.AreEqual("9月7日 15:00", rows[0].Reset);
        Assert.AreEqual("7 天", rows[1].Label);
        Assert.AreEqual(90, rows[1].RemainingPercent);
        Assert.AreEqual("9月11日 12:00", rows[1].Reset);
    }

    [TestMethod]
    public void DefaultBadgeUsesTheBuiltProductVersionRatherThanAHistoricalLiteral()
    {
        var attribute = (System.Reflection.AssemblyInformationalVersionAttribute)typeof(QuotaDetailFormatter).Assembly
            .GetCustomAttributes(typeof(System.Reflection.AssemblyInformationalVersionAttribute), false).Single();
        var expected = attribute.InformationalVersion.Split('+')[0];
        var content = QuotaDetailFormatter.Format(Snapshot, Now, DisplayLanguage.English, TimeZoneInfo.Utc);
        Assert.AreEqual(expected, content.Version);
    }

    private static readonly DateTimeOffset Now = new(2026, 9, 7, 12, 0, 0, TimeSpan.Zero);
    private static AllowanceSnapshot Snapshot => new(24, 76, Now.AddHours(3), Now,
        300, "plus", null, new BankResetSummary(1,
            [new BankResetCredit("available", null, Now.AddDays(2).AddHours(6), null, null)]),
        new QuotaWindowSnapshot(10, 90, Now.AddDays(4), 10_080));

    [TestMethod]
    public void ResetAndBankRowsMatchCurrentMacTwoLinePresentation()
    {
        var content = QuotaDetailFormatter.Format(Snapshot, Now, DisplayLanguage.SimplifiedChinese, TimeZoneInfo.Utc);
        Assert.IsFalse(content.Rows.Any(row => row.Label.Contains("额度周期")));
        Assert.AreEqual("0天3小时\n（2026/09/07 15:00）", content.Rows.Single(row => row.Label == "下次重置（5小时）").Value);
        Assert.AreEqual("4天0小时\n（2026/09/11 12:00）", content.Rows.Single(row => row.Label == "下次重置（7天）").Value);
        Assert.AreEqual("2天6小时\n（2026/09/09 18:00）", content.Rows.Single(row => row.Label == "Bank 1到期时间").Value);
        Assert.AreEqual("Credits", content.Rows[^2].Label);
        Assert.AreEqual(76, content.Rows.Single(row => row.Label == "下次重置（5小时）").AccentRemainingPercent);
        Assert.AreEqual(90, content.Rows.Single(row => row.Label == "下次重置（7天）").AccentRemainingPercent);
        Assert.AreEqual(10, content.Rows.Single(row => row.Label == "Bank 1到期时间").AccentRemainingPercent);
        Assert.IsTrue(content.Rows.Single(row => row.Label == "Bank 1到期时间").EmphasizeCountdown);
    }

    [TestMethod]
    public void WeeklyTokensIncludeTodayAndCombineDuplicateDaysButExcludeFutureBuckets()
    {
        var usage = new TokenUsageSnapshot(Now,
            [new(new(2026, 9, 3), 999), new(new(2026, 9, 4), 10),
             new(new(2026, 9, 7), 20), new(new(2026, 9, 7), 30), new(new(2026, 9, 8), 999)],
            null, TokenUsageAvailability.Available);
        var content = QuotaDetailFormatter.Format(Snapshot, Now, DisplayLanguage.English, TimeZoneInfo.Utc, usage);
        Assert.AreEqual(new DateOnly(2026, 9, 4), content.TokenUsage!.Days[0].Date);
        Assert.AreEqual(new DateOnly(2026, 9, 10), content.TokenUsage.Days[^1].Date);
        Assert.AreEqual(60L, content.TokenUsage.CurrentPeriodTotal);
        Assert.AreEqual(50L, content.TokenUsage.Days.Single(day => day.IsCurrent).Tokens);
        Assert.AreEqual(0L, content.TokenUsage.Days.Single(day => day.Date == new DateOnly(2026, 9, 8)).Tokens);
    }

    [DataTestMethod]
    [DataRow("2天6小时\n（2026/09/09 18:00）")]
    [DataRow("2天6小時\n（2026/09/09 18:00）")]
    [DataRow("2d 6h\n(2026/09/09 18:00)")]
    public void OnlyCountdownDigitsAreEmphasized(string value)
    {
        var segments = QuotaCountdownSegmenter.Segments(value);
        CollectionAssert.AreEqual(new[] { "2", "6" }, segments.Where(s => s.Role == QuotaCountdownSegmentRole.Digits).Select(s => s.Text).ToArray());
        Assert.AreEqual(value, string.Concat(segments.Select(s => s.Text)));
        Assert.IsTrue(segments.Last().Text.Contains("2026/09/09"));
        Assert.AreEqual(QuotaCountdownSegmentRole.Plain, segments.Last().Role);
    }

    [TestMethod]
    public void OverflowIsUnavailableInsteadOfCrashingOrPublishingWrappedTokenTotals()
    {
        var usage = new TokenUsageSnapshot(Now,
            [new(new(2026, 9, 7), long.MaxValue), new(new(2026, 9, 7), 1)],
            null, TokenUsageAvailability.Available);
        var content = QuotaDetailFormatter.Format(Snapshot, Now, DisplayLanguage.English, TimeZoneInfo.Utc, usage);
        Assert.AreEqual(TokenUsageAvailability.Unavailable, content.TokenUsage!.Availability);
        Assert.AreEqual(0L, content.TokenUsage.CurrentPeriodTotal);
        Assert.IsTrue(content.TokenUsage.Days.All(day => day.Tokens == 0));
    }

    [TestMethod]
    public void InvalidWindowRetainsSevenDaysWithUnavailableTotal()
    {
        var snapshot = Snapshot with { WindowDurationMinutes = null, Secondary = null };
        var usage = new TokenUsageSnapshot(Now, [], null, TokenUsageAvailability.Available);
        var cycle = TokenUsageWindow.Resolve(snapshot, usage, Now, TimeZoneInfo.Utc);
        Assert.AreEqual(new DateOnly(2026, 9, 1), cycle.FirstDay);
        Assert.AreEqual(TokenUsageAvailability.Unavailable, cycle.Availability);
    }

    [TestMethod]
    public void PeriodStartSubtractsHoursBeforeConvertingToTheLocalDay()
    {
        var zone = TimeZoneInfo.CreateCustomTimeZone("fixture+8", TimeSpan.FromHours(8), "fixture+8", "fixture+8");
        var snapshot = Snapshot with { ResetsAt = new DateTimeOffset(2026, 9, 7, 3, 0, 0, TimeSpan.Zero), Secondary = null };
        var usage = new TokenUsageSnapshot(Now, [], null, TokenUsageAvailability.Available);
        var cycle = TokenUsageWindow.Resolve(snapshot, usage, Now, zone);
        Assert.AreEqual(new DateOnly(2026, 9, 7), cycle.FirstDay);
    }
}
