using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Windows.Tests;

[TestClass]
public sealed class Win32CodexWindowLocatorTests
{
    [TestMethod]
    public void KeepsPerMonitorV2WindowRectInPhysicalScreenPixels()
    {
        var bounds = WindowsCoordinateSpace.ToPhysicalBounds(
            left: -7,
            top: -7,
            right: 1506,
            bottom: 958,
            dpiScale: 2);

        Assert.AreEqual(new RectD(-7, -7, 1513, 965), bounds);
    }

    [TestMethod]
    public void PreservesOnlyAUniqueVerifiedCaptionContainerBounds()
    {
        var host = new RectD(-1600, 100, 1000, 700);
        var caption = new RectD(-1600, 100, 1000, 50);

        Assert.AreEqual(caption, HostWindowGeometry.TryResolveVerifiedCaptionBounds(host, [caption]));
        Assert.IsNull(HostWindowGeometry.TryResolveVerifiedCaptionBounds(host, [caption, caption]));
        Assert.IsNull(HostWindowGeometry.TryResolveVerifiedCaptionBounds(host, [new RectD(-1601, 100, 1000, 50)]));
    }

    [TestMethod]
    public void DoesNotPreserveAnUnverifiedCaptionContainer()
    {
        var host = new RectD(-1600, 100, 1000, 700);
        var caption = new RectD(-1600, 100, 1000, 50);

        Assert.IsNull(HostWindowGeometry.TryResolveVerifiedCaptionBounds(
            host,
            [new HostWindowGeometry.CaptionBoundsCandidate(caption, IsVerified: false)],
            dpiScale: 1.25));
    }
}
