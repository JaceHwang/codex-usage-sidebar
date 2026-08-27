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
        return new RectD(
            left,
            top,
            right - left,
            bottom - top);
    }
}

internal static class HostWindowGeometry
{
    internal readonly record struct CaptionBoundsCandidate(RectD Bounds, bool IsVerified);

    internal static RectD? TryResolveVerifiedCaptionBounds(
        RectD hostBounds,
        IReadOnlyList<RectD> candidates,
        double dpiScale = 1)
    {
        return TryResolveVerifiedCaptionBounds(
            hostBounds,
            candidates.Select(candidate => new CaptionBoundsCandidate(candidate, IsVerified: true)).ToArray(),
            dpiScale);
    }

    internal static RectD? TryResolveVerifiedCaptionBounds(
        RectD hostBounds,
        IReadOnlyList<CaptionBoundsCandidate> candidates,
        double dpiScale = 1)
    {
        if (!IsUsable(hostBounds)
            || !double.IsFinite(dpiScale)
            || dpiScale <= 0)
        {
            return null;
        }

        var verified = candidates.Where(candidate =>
            candidate.IsVerified
            && IsUsable(candidate.Bounds)
            && Contains(hostBounds, candidate.Bounds)
            && candidate.Bounds.Y >= hostBounds.Y - (2 * dpiScale)
            && candidate.Bounds.Bottom <= hostBounds.Y + Math.Min(64 * dpiScale, hostBounds.Height)).ToArray();
        return verified.Length == 1 ? verified[0].Bounds : null;
    }

    private static bool Contains(RectD container, RectD candidate) =>
        candidate.X >= container.X
        && candidate.Y >= container.Y
        && candidate.Right <= container.Right
        && candidate.Bottom <= container.Bottom;

    private static bool IsUsable(RectD bounds) =>
        double.IsFinite(bounds.X)
        && double.IsFinite(bounds.Y)
        && double.IsFinite(bounds.Width)
        && double.IsFinite(bounds.Height)
        && bounds.Width > 0
        && bounds.Height > 0;
}
