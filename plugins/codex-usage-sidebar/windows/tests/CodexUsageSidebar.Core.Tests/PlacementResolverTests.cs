using System.Text.Json;
using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Core.Tests;

[TestClass]
public sealed class PlacementResolverTests
{
    [TestMethod]
    public void UsesContentToolbarWhenPreferredSlotFits()
    {
        var fixture = JsonSerializer.Deserialize<PlacementFixture>(
            File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "contracts", "placement", "content-toolbar.json")),
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true })!;

        var result = PlacementResolver.Resolve(
            fixture.Window,
            fixture.PreferredAnchorTrailingEdge,
            fixture.Indicator.Width,
            fixture.Indicator.Gap,
            fixture.Obstacles);

        Assert.AreEqual(PlacementSurface.Content, result.Surface);
        Assert.AreEqual(fixture.Expected.X, result.Frame.X, 0.001);
    }

    [TestMethod]
    public void MovesToRightToolbarOnlyWhenNoCollisionFreeContentSlotRemains()
    {
        var window = new RectD(0, 0, 1200, 800);
        var obstacles = new[] { new RectD(0, 750, 1_000, 50) };
        var result = PlacementResolver.Resolve(window, 950, 208, 8, obstacles);
        Assert.AreEqual(PlacementSurface.RightToolbar, result.Surface);
    }

    public sealed record PlacementFixture(
        RectD Window,
        IndicatorFixture Indicator,
        double PreferredAnchorTrailingEdge,
        IReadOnlyList<RectD> Obstacles,
        ExpectedFixture Expected);
    public sealed record IndicatorFixture(double Width, double Gap);
    public sealed record ExpectedFixture(string Surface, double X);
}
