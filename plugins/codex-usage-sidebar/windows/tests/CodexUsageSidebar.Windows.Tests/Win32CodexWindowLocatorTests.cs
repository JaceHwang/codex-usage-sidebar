using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Windows.Tests;

[TestClass]
public sealed class Win32CodexWindowLocatorTests
{
    [TestMethod]
    public void ConvertsVirtualizedWindowRectToThePhysicalUiaCoordinateSpace()
    {
        var bounds = WindowsCoordinateSpace.ToPhysicalBounds(
            left: -7,
            top: -7,
            right: 1506,
            bottom: 958,
            dpiScale: 2);

        Assert.AreEqual(new RectD(-14, -14, 3026, 1930), bounds);
    }
}
