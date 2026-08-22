using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Windows;

internal static class WindowsCoordinateSpace
{
    internal static RectD ToPhysicalBounds(
        int left,
        int top,
        int right,
        int bottom,
        double dpiScale)
    {
        if (!double.IsFinite(dpiScale) || dpiScale <= 0)
        {
            return new RectD(left, top, right - left, bottom - top);
        }

        return new RectD(
            left * dpiScale,
            top * dpiScale,
            (right - left) * dpiScale,
            (bottom - top) * dpiScale);
    }
}
