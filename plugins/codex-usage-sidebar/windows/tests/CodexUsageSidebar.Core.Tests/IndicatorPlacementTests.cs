using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Core.Tests;

[TestClass]
public sealed class IndicatorPlacementTests
{
    [TestMethod]
    public void ManualPositionDoesNotFollowHostMovementAndRemembersEachDisplay()
    {
        var preferences = new IndicatorPlacementPreferences();
        var workArea = new RectD(-1920, 40, 1920, 1040);
        preferences.Capture("left", new(-1500, 300, 200, 40), workArea);
        preferences.Capture("right", new(900, 500, 200, 40), new(0, 0, 1920, 1080));
        preferences.Mode = IndicatorPlacementMode.Locked;
        Assert.AreEqual(new RectD(-1500, 300, 200, 40),
            preferences.Resolve("left", workArea, new(-800, 70, 200, 40)));
        Assert.AreEqual("right", preferences.ActiveDisplayId);
        preferences.Mode = IndicatorPlacementMode.Automatic;
        Assert.AreEqual(new RectD(-800, 70, 200, 40),
            preferences.Resolve("left", workArea, new(-800, 70, 200, 40)));
    }

    [TestMethod]
    public void NormalizedPlacementStaysOnScreenAfterResolutionAndButtonSizeChange()
    {
        var placement = IndicatorManualPlacement.Capture(new(900, 760, 100, 40), new(0, 0, 1000, 800));
        Assert.AreEqual(new RectD(760, 560, 240, 40), placement.Resolve(new(0, 0, 1000, 600), 240, 40));
        Assert.AreEqual(new RectD(0, 0, 240, 40), placement.Resolve(new(0, 0, 200, 30), 240, 40));
    }

    [DataTestMethod]
    [DataRow(IndicatorPlacementMode.Automatic)]
    [DataRow(IndicatorPlacementMode.Locked)]
    public void NonFreeModesCannotStartOrContinueDragging(IndicatorPlacementMode mode)
    {
        var drag = new IndicatorDragSession();
        drag.Begin(100, 100, new(80, 80, 200, 28));
        Assert.IsNull(drag.Update(300, 300, mode));
        Assert.IsFalse(drag.End());
        drag.Begin(100, 100, new(80, 80, 200, 28));
        Assert.IsNotNull(drag.Update(150, 150, IndicatorPlacementMode.Free));
        Assert.IsNull(drag.Update(200, 200, mode));
    }

    [TestMethod]
    public void DragUsesAbsoluteScreenDeltaWithoutAccumulationOrDpiDrift()
    {
        var drag = new IndicatorDragSession();
        drag.Begin(-1200, 200, new(-1220, 180, 400, 56), 2);
        Assert.IsNull(drag.Update(-1195, 200, IndicatorPlacementMode.Free));
        Assert.AreEqual(new RectD(-1190, 210, 400, 56), drag.Update(-1170, 230, IndicatorPlacementMode.Free));
        Assert.AreEqual(new RectD(-1180, 220, 400, 56), drag.Update(-1160, 240, IndicatorPlacementMode.Free));
        Assert.IsTrue(drag.End());
        Assert.IsNull(drag.Update(-1100, 300, IndicatorPlacementMode.Free));
        Assert.IsFalse(drag.End());
    }
}
