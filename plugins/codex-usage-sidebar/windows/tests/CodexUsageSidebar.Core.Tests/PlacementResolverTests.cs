using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Core.Tests;

[TestClass]
public sealed class PlacementResolverTests
{
    [TestMethod]
    public void UsesTheExactOpenLocationSlotWhenTheCompleteFrameClearsTheTitle()
    {
        var result = PlacementResolver.ResolveResponsive(
            toolbarBounds: new RectD(478, 70, 2522, 92),
            openLocationBounds: new RectD(2620, 88, 182, 56),
            titleBounds: new RectD(494, 88, 542, 56),
            indicatorWidth: 328,
            gap: 16,
            localObstacles:
            [
                new RectD(2620, 88, 182, 56),
                new RectD(2802, 88, 46, 56),
                new RectD(2860, 88, 56, 56),
            ],
            rightToolbarBounds: default,
            rightObstacles: []);

        Assert.IsNotNull(result);
        Assert.AreEqual(PlacementSurface.Content, result.Value.Surface);
        Assert.AreEqual(new RectD(2276, 88, 328, 56), result.Value.Frame);
    }

    [TestMethod]
    public void PrefersTheMiddleTitlebarWhenItHasEnoughSpaceEvenIfTheRightPaneIsAvailable()
    {
        var result = PlacementResolver.ResolveResponsive(
            toolbarBounds: new RectD(478, 70, 2522, 92),
            openLocationBounds: new RectD(2620, 88, 182, 56),
            titleBounds: new RectD(494, 88, 542, 56),
            indicatorWidth: 328,
            gap: 16,
            localObstacles:
            [
                new RectD(2620, 88, 182, 56),
                new RectD(2802, 88, 46, 56),
                new RectD(2860, 88, 56, 56),
            ],
            rightToolbarBounds: new RectD(1395, 70, 1461, 92),
            rightObstacles: [new RectD(2856, 88, 56, 56)]);

        Assert.IsNotNull(result);
        Assert.AreEqual(PlacementSurface.Content, result.Value.Surface);
        Assert.AreEqual(new RectD(2276, 88, 328, 56), result.Value.Frame);
    }

    [TestMethod]
    public void UsesValidatedRightToolbarWhenTheLocalFrameWouldOverlapTheTitle()
    {
        var result = ResolveNarrow();

        Assert.IsNotNull(result);
        Assert.AreEqual(PlacementSurface.RightToolbar, result.Value.Surface);
        Assert.AreEqual(new RectD(2512, 88, 328, 56), result.Value.Frame);
    }

    [TestMethod]
    public void HidesWhenTheRightToolbarCannotContainTheFallback()
    {
        var result = PlacementResolver.ResolveResponsive(
            new RectD(478, 70, 1000, 92),
            new RectD(1069, 88, 183, 56),
            new RectD(494, 88, 533, 56),
            328,
            16,
            [new RectD(1069, 88, 183, 56)],
            new RectD(2700, 70, 140, 92),
            [new RectD(2856, 88, 56, 56)]);

        Assert.IsNull(result);
    }

    [TestMethod]
    public void UsesTheLeftmostRightObstacleAsTheFallbackBoundary()
    {
        var result = PlacementResolver.ResolveResponsive(
            new RectD(478, 70, 2522, 92),
            new RectD(1069, 88, 183, 56),
            new RectD(494, 88, 533, 56),
            328,
            16,
            [new RectD(1069, 88, 183, 56)],
            new RectD(1395, 70, 1461, 92),
            [new RectD(2600, 88, 40, 56), new RectD(2856, 88, 56, 56)]);

        Assert.IsNotNull(result);
        Assert.AreEqual(new RectD(2256, 88, 328, 56), result.Value.Frame);
    }

    [TestMethod]
    public void HidesWhenResponsiveGeometryIsMissingOrNonFinite()
    {
        Assert.IsNull(PlacementResolver.ResolveResponsive(
            new RectD(0, 0, 1000, 92), default, default, 328, 16, [], default, []));
        Assert.IsNull(PlacementResolver.ResolveResponsive(
            new RectD(0, 0, 1000, 92),
            new RectD(double.NaN, 18, 182, 56),
            new RectD(10, 18, 100, 56),
            328,
            16,
            [],
            default,
            []));
    }

    [TestMethod]
    public void RecomputingAfterSpaceReturnsRestoresTheLocalPlacement()
    {
        Assert.AreEqual(PlacementSurface.RightToolbar, ResolveNarrow()!.Value.Surface);

        var restored = PlacementResolver.ResolveResponsive(
            new RectD(478, 70, 2522, 92),
            new RectD(2620, 88, 182, 56),
            new RectD(494, 88, 542, 56),
            328,
            16,
            [new RectD(2620, 88, 182, 56)],
            default,
            []);

        Assert.AreEqual(PlacementSurface.Content, restored!.Value.Surface);
        Assert.AreEqual(new RectD(2276, 88, 328, 56), restored.Value.Frame);
    }

    private static PlacementResult? ResolveNarrow() => PlacementResolver.ResolveResponsive(
        toolbarBounds: new RectD(478, 70, 2522, 92),
        openLocationBounds: new RectD(1069, 88, 183, 56),
        titleBounds: new RectD(494, 88, 533, 56),
        indicatorWidth: 328,
        gap: 16,
        localObstacles:
        [
            new RectD(1069, 88, 183, 56),
            new RectD(1251, 88, 47, 56),
            new RectD(1309, 88, 57, 56),
        ],
        rightToolbarBounds: new RectD(1395, 70, 1461, 92),
        rightObstacles: [new RectD(2856, 88, 56, 56)]);
}
