using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Core.Tests;

[TestClass]
public sealed class QuotaDetailContentComparerTests
{
    private static QuotaDetailContent Card => new("Codex quota", 80, [new("Next reset", "3h")],
        new("Token usage", TokenUsageAvailability.Available,
            [new(new(2026, 9, 8), "Sep 8", "10", 10, true)], 10, "10 tokens", "Unavailable", null),
        QuotaWindows: [new("5 hours", 80), new("7 days", 90)]);

    [TestMethod]
    public void RepeatedEquivalentRefreshDoesNotReplaceTheVisibleCard()
    {
        Assert.IsTrue(QuotaDetailContentComparer.Equivalent(Card, Card));
    }

    [TestMethod]
    public void ChangesToRowsQuotaColorsOrTokenDaysInvalidateTheCard()
    {
        var card = Card;
        Assert.IsFalse(QuotaDetailContentComparer.Equivalent(card, card with { Rows = [new("Next reset", "2h")] }));
        Assert.IsFalse(QuotaDetailContentComparer.Equivalent(card, card with { QuotaWindows = [new("5 hours", 80), new("7 days", 70)] }));
        Assert.IsFalse(QuotaDetailContentComparer.Equivalent(card, card with { TokenUsage = card.TokenUsage! with
            { Days = [new(new(2026, 9, 8), "Sep 8", "20", 20, true)] } }));
        Assert.IsFalse(QuotaDetailContentComparer.Equivalent(card, card with { Version = "different" }));
        Assert.IsFalse(QuotaDetailContentComparer.Equivalent(null, card));
    }
}
