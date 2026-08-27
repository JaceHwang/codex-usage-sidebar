using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Windows;

public sealed record UiaStructureNode(
    int Depth,
    string ControlType,
    string AutomationId,
    string ClassName,
    RectD Bounds,
    int NameLength,
    string SemanticRole = "");

public static class RightToolbarCandidatePolicy
{
    public static bool IsCandidate(
        RectD openLocationBounds,
        RectD candidateBounds,
        string controlType,
        string className,
        double dpiScale) =>
        controlType == "ControlType.Button"
        && className.Contains("h-token-button-composer", StringComparison.Ordinal)
        && className.Contains("aspect-square", StringComparison.Ordinal)
        && double.IsFinite(dpiScale)
        && dpiScale > 0
        && candidateBounds.Width > 0
        && candidateBounds.Height > 0
        && candidateBounds.X >= openLocationBounds.Right
        && Math.Abs(candidateBounds.Y - openLocationBounds.Y) <= 2 * dpiScale
        && Math.Abs(candidateBounds.Height - openLocationBounds.Height) <= 2 * dpiScale;
}

public static class OpenLocationSeedCandidatePolicy
{
    public static bool IsCandidate(
        string controlType,
        string className,
        RectD candidateBounds,
        RectD hostBounds,
        double dpiScale) =>
        controlType == "ControlType.Button"
        && className.Contains("h-token-button-composer", StringComparison.Ordinal)
        && className.Contains("rounded-e-none", StringComparison.Ordinal)
        && !className.Contains("rounded-s-none", StringComparison.Ordinal)
        && IsUsable(candidateBounds)
        && IsUsable(hostBounds)
        && double.IsFinite(dpiScale)
        && dpiScale > 0
        && Contains(hostBounds, candidateBounds)
        && candidateBounds.Y <= hostBounds.Y + (90 * dpiScale)
        && candidateBounds.Height >= 20 * dpiScale
        && candidateBounds.Height <= 36 * dpiScale
        && candidateBounds.Width >= 20 * dpiScale
        && candidateBounds.Width <= 140 * dpiScale;

    private static bool Contains(RectD container, RectD child) =>
        child.X >= container.X
        && child.Y >= container.Y
        && child.Right <= container.Right
        && child.Bottom <= container.Bottom;

    private static bool IsUsable(RectD bounds) =>
        double.IsFinite(bounds.X)
        && double.IsFinite(bounds.Y)
        && double.IsFinite(bounds.Width)
        && double.IsFinite(bounds.Height)
        && bounds.Width > 0
        && bounds.Height > 0;
}

public static class CodexTitlebarSelector
{
    public static TitlebarSnapshot? TryResolve(
        string buildIdentity,
        double dpiScale,
        RectD hostBounds,
        IReadOnlyList<UiaStructureNode> nodes)
        => TryResolve(buildIdentity, dpiScale, hostBounds, nodes, SelectorProfileCatalog.Default);

    public static TitlebarSnapshot? TryResolve(
        string buildIdentity,
        double dpiScale,
        RectD hostBounds,
        IReadOnlyList<UiaStructureNode> nodes,
        SelectorProfileCatalog catalog)
    {
        ArgumentNullException.ThrowIfNull(catalog);
        foreach (var profile in catalog.ProfilesFor(buildIdentity))
        {
            var snapshot = AdaptiveTitlebarResolver.TryResolve(dpiScale, hostBounds, nodes, profile);
            if (snapshot is not null) return snapshot;
        }
        return null;
    }
}
