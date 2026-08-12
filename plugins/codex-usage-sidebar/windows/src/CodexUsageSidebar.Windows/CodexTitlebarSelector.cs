using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Windows;

public sealed record UiaStructureNode(
    int Depth,
    string ControlType,
    string AutomationId,
    string ClassName,
    RectD Bounds,
    int NameLength);

public static class CodexTitlebarSelector
{
    private const string ValidatedBuildIdentity = "151.0.7922.76";
    private const string PaneControlType = "ControlType.Pane";
    private const string ButtonControlType = "ControlType.Button";
    private const string CaptionContainerClass = "ChromeNodeCaptionButtonContainer";
    private const string CaptionButtonClass = "ChromeNodeCaptionButton";
    private static readonly string[] RequiredCaptionButtonIds =
        ["view_1", "view_2", "view_3", "view_4"];

    public static TitlebarSnapshot? TryResolve(
        string buildIdentity,
        double dpiScale,
        RectD hostBounds,
        IReadOnlyList<UiaStructureNode> nodes)
    {
        if (!string.Equals(buildIdentity, ValidatedBuildIdentity, StringComparison.Ordinal)
            || !double.IsFinite(dpiScale)
            || dpiScale <= 0)
        {
            return null;
        }

        var containers = nodes.Where(node =>
            node.ControlType == PaneControlType
            && node.ClassName == CaptionContainerClass
            && node.AutomationId.Length == 0).ToArray();
        if (containers.Length != 1)
        {
            return null;
        }

        var containerNode = containers[0];
        var captionButtons = new List<UiaStructureNode>();
        foreach (var automationId in RequiredCaptionButtonIds)
        {
            var matches = nodes.Where(node =>
                node.ControlType == ButtonControlType
                && node.ClassName == CaptionButtonClass
                && node.AutomationId == automationId
                && node.Depth == containerNode.Depth + 1
                && Contains(containerNode.Bounds, node.Bounds)).ToArray();
            if (matches.Length != 1)
            {
                return null;
            }
            captionButtons.Add(matches[0]);
        }

        // GetWindowRect and UI Automation both report physical screen pixels in
        // the PMv2-aware host. Keep the selector in that coordinate space; a
        // global X/Y value cannot safely be converted by dividing by one
        // monitor's scale when monitor origins use different DPI values.
        var container = containerNode.Bounds;
        var titlebarBottom = hostBounds.Y + Math.Min(64 * dpiScale, hostBounds.Height);
        if (container.Width <= 0
            || container.Height <= 0
            || container.X < hostBounds.X
            || container.Right > hostBounds.Right
            || container.Y < hostBounds.Y - (2 * dpiScale)
            || container.Bottom > titlebarBottom)
        {
            return null;
        }

        return new TitlebarSnapshot(container.X, [container]);
    }

    private static bool Contains(RectD container, RectD child) =>
        child.Width > 0
        && child.Height > 0
        && child.X >= container.X
        && child.Y >= container.Y
        && child.Right <= container.Right
        && child.Bottom <= container.Bottom;
}
