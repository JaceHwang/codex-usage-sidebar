using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Core.Tests;

[TestClass]
public sealed class QuotaCountdownSegmentTests
{
    [TestMethod]
    public void EmphasizesOnlyDigitsInTheFinalFullWidthCountdown()
    {
        var segments = QuotaCountdownSegmenter.Segments("8月19日 20:51（6d19h）");

        CollectionAssert.AreEqual(
            new[] { "8月19日 20:51", "（", "6", "d", "19", "h", "）" },
            segments.Select(segment => segment.Text).ToArray());
        CollectionAssert.AreEqual(
            new[]
            {
                QuotaCountdownSegmentRole.Plain,
                QuotaCountdownSegmentRole.Punctuation,
                QuotaCountdownSegmentRole.Digits,
                QuotaCountdownSegmentRole.Unit,
                QuotaCountdownSegmentRole.Digits,
                QuotaCountdownSegmentRole.Unit,
                QuotaCountdownSegmentRole.Punctuation,
            },
            segments.Select(segment => segment.Role).ToArray());
    }

    [DataTestMethod]
    [DataRow("Aug 19, 20:51 (<1m)", "1|m")]
    [DataRow("Aug 19, 20:51 (2d1h ago)", "2|d|1|h| ago")]
    [DataRow("8月19日 20:51（3h前）", "3|h|前")]
    public void SupportsMinutePastAndLocalizedSuffixForms(string value, string expectedInterval)
    {
        var styled = QuotaCountdownSegmenter.Segments(value)
            .Where(segment => segment.Role is not QuotaCountdownSegmentRole.Plain
                and not QuotaCountdownSegmentRole.Punctuation)
            .ToArray();

        Assert.AreEqual(expectedInterval, string.Join('|', styled.Select(segment => segment.Text)));
        Assert.IsTrue(styled.Any(segment => segment.Role == QuotaCountdownSegmentRole.Digits));
        Assert.IsTrue(styled.Any(segment => segment.Role == QuotaCountdownSegmentRole.Unit));
        if (value.Contains('<'))
        {
            Assert.IsTrue(QuotaCountdownSegmenter.Segments(value).Any(segment =>
                segment.Role == QuotaCountdownSegmentRole.Punctuation
                && segment.Text.Contains('<')));
        }
    }

    [TestMethod]
    public void LeavesMalformedOrUnrelatedParenthesizedTextPlain()
    {
        var segments = QuotaCountdownSegmenter.Segments("8月19日 20:51（soon）");

        Assert.AreEqual(1, segments.Count);
        Assert.AreEqual("8月19日 20:51（soon）", segments[0].Text);
        Assert.AreEqual(QuotaCountdownSegmentRole.Plain, segments[0].Role);
    }

    [TestMethod]
    public void StylesOnlyTheLastValidParenthesizedInterval()
    {
        var segments = QuotaCountdownSegmenter.Segments("label (not time) 8月19日（6d19h）");

        Assert.AreEqual("label (not time) 8月19日", segments[0].Text);
        CollectionAssert.AreEqual(
            new[] { "6", "19" },
            segments.Where(segment => segment.Role == QuotaCountdownSegmentRole.Digits)
                .Select(segment => segment.Text)
                .ToArray());
    }
}
