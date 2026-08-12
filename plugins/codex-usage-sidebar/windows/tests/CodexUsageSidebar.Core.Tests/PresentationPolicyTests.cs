using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Core.Tests;

[TestClass]
public sealed class PresentationPolicyTests
{
    [TestMethod]
    public void MapsCodexLocalesAndFallsBackToEnglish()
    {
        Assert.AreEqual(DisplayLanguage.SimplifiedChinese, LanguageResolver.Resolve("zh-Hans-CN"));
        Assert.AreEqual(DisplayLanguage.TraditionalChinese, LanguageResolver.Resolve("zh-Hant-TW"));
        Assert.AreEqual(DisplayLanguage.English, LanguageResolver.Resolve("ja-JP"));
    }

    [TestMethod]
    public void FormatsCompactDurationWithLargeNumerals()
    {
        var segments = RelativeIntervalFormatter.Format(
            TimeSpan.FromDays(5) + TimeSpan.FromHours(21),
            DisplayLanguage.English);

        CollectionAssert.AreEqual(new[] { "5", "d", "21", "h" }, segments.Select(x => x.Text).ToArray());
        CollectionAssert.AreEqual(new[] { true, false, true, false }, segments.Select(x => x.IsEmphasized).ToArray());
    }

    [TestMethod]
    public void InterpolatesGreenOrangeAndRedQuotaColors()
    {
        Assert.AreEqual(new HsbColor(0.36, 0.78, 0.82), QuotaColorScale.ForRemainingPercent(100));
        Assert.AreEqual(new HsbColor(0.078, 0.96, 1), QuotaColorScale.ForRemainingPercent(49));
        Assert.AreEqual(new HsbColor(0, 0.86, 1), QuotaColorScale.ForRemainingPercent(10));
    }

    [TestMethod]
    public void ClickPinsAndSecondClickSuppressesHoverUntilPointerExits()
    {
        var state = DetailInteractionState.Initial.PointerChanged(true).TogglePinned(true);
        Assert.IsTrue(state.ShouldShowDetail);
        state = state.TogglePinned(true);
        Assert.IsFalse(state.ShouldShowDetail);
        state = state.PointerChanged(false).PointerChanged(true);
        Assert.IsTrue(state.ShouldShowDetail);
    }

    [TestMethod]
    public void IdleIndicatorRetainsAnInvisibleHitTestSurface()
    {
        Assert.AreEqual((byte)1, IndicatorHitTestPolicy.BackgroundAlpha(highlighted: false));
        Assert.AreEqual((byte)18, IndicatorHitTestPolicy.BackgroundAlpha(highlighted: true));
    }

    [TestMethod]
    public void RefreshPolicyUsesOneSecondForegroundAndFiveSecondBackgroundIntervals()
    {
        Assert.AreEqual(TimeSpan.FromSeconds(1), RefreshPolicy.Interval(true));
        Assert.AreEqual(TimeSpan.FromSeconds(5), RefreshPolicy.Interval(false));
        Assert.AreEqual(SnapshotFreshness.Dimmed, RefreshPolicy.Freshness(DateTimeOffset.UnixEpoch, DateTimeOffset.UnixEpoch.AddSeconds(120)));
        Assert.AreEqual(SnapshotFreshness.Hidden, RefreshPolicy.Freshness(DateTimeOffset.UnixEpoch, DateTimeOffset.UnixEpoch.AddSeconds(300)));
    }
}
