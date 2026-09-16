using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Windows;

public readonly record struct HostPageControl(RectD Bounds, string Label);

public static class HostPagePolicy
{
    public static bool IsSettingsNavigation(
        HostPageControl control,
        RectD hostBounds,
        bool allowStructuralMatch)
    {
        var frame = control.Bounds;
        if (!Usable(frame) || !Usable(hostBounds)
            || frame.Width > 320 || frame.Height > 64
            || frame.X > hostBounds.X + hostBounds.Width * 0.35
            || frame.Y < hostBounds.Y || frame.Y > hostBounds.Y + 120)
        {
            return false;
        }
        var label = control.Label.Trim().Replace('-', ' ').Replace('_', ' ').ToLowerInvariant();
        return label.Contains("返回应用", StringComparison.Ordinal)
            || label.Contains("返回應用", StringComparison.Ordinal)
            || label.Contains("back to app", StringComparison.Ordinal)
            || (allowStructuralMatch && frame.Width >= 100);
    }

    private static bool Usable(RectD frame) =>
        double.IsFinite(frame.X) && double.IsFinite(frame.Y)
        && double.IsFinite(frame.Width) && double.IsFinite(frame.Height)
        && frame.Width > 0 && frame.Height > 0;
}
