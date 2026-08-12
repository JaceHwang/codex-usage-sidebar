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

public static class CodexTitlebarSelector
{
    private const string ValidatedBuildIdentity = "151.0.7922.76";
    private const string PaneControlType = "ControlType.Pane";
    private const string ButtonControlType = "ControlType.Button";
    private const string GroupControlType = "ControlType.Group";
    private const string CaptionContainerClass = "ChromeNodeCaptionButtonContainer";
    private const string CaptionButtonClass = "ChromeNodeCaptionButton";
    private const string ToolbarClassMarker = "fixed z-30 flex h-toolbar";
    private const string ToolbarPositionMarker = "top-toolbar-sm";
    private const string ContentGroupClassMarker = "flex h-full min-w-0 flex-1";
    private const string ComposerButtonClassMarker = "h-token-button-composer";
    private const string OpenLocationEndClassMarker = "rounded-e-none";
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
        var captionIdentityBounds = Expand(containerNode.Bounds, 2 * dpiScale);
        var captionButtons = new List<UiaStructureNode>();
        foreach (var automationId in RequiredCaptionButtonIds)
        {
            var matches = nodes.Where(node =>
                node.ControlType == ButtonControlType
                && node.ClassName == CaptionButtonClass
                && node.AutomationId == automationId
                && node.Depth == containerNode.Depth + 1
                && Contains(captionIdentityBounds, node.Bounds)).ToArray();
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

        var toolbars = nodes.Where(node =>
            node.ControlType == GroupControlType
            && node.ClassName.Contains(ToolbarClassMarker, StringComparison.Ordinal)
            && node.ClassName.Contains(ToolbarPositionMarker, StringComparison.Ordinal)
            && Contains(hostBounds, node.Bounds)).ToArray();
        if (toolbars.Length != 1)
        {
            return null;
        }

        var toolbar = toolbars[0];
        var contentGroups = nodes.Where(node =>
            node.ControlType == GroupControlType
            && node.Depth == toolbar.Depth + 1
            && node.ClassName.Contains(ContentGroupClassMarker, StringComparison.Ordinal)
            && Contains(toolbar.Bounds, node.Bounds)).ToArray();
        if (contentGroups.Length != 1)
        {
            return null;
        }

        var contentGroup = contentGroups[0];
        var openLocationButtons = nodes.Where(node =>
            node.ControlType == ButtonControlType
            && node.Depth == contentGroup.Depth + 1
            && node.SemanticRole == UiaSemanticRoles.OpenLocation
            && node.ClassName.Contains(ComposerButtonClassMarker, StringComparison.Ordinal)
            && node.ClassName.Contains(OpenLocationEndClassMarker, StringComparison.Ordinal)
            && Contains(contentGroup.Bounds, node.Bounds)).ToArray();
        if (openLocationButtons.Length != 1)
        {
            return null;
        }

        var openLocation = openLocationButtons[0];
        var obstacles = nodes.Where(node =>
                node.ControlType == ButtonControlType
                && node.Depth == openLocation.Depth
                && node.ClassName.Contains(ComposerButtonClassMarker, StringComparison.Ordinal)
                && node.Bounds.X >= openLocation.Bounds.X
                && Contains(contentGroup.Bounds, node.Bounds))
            .OrderBy(node => node.Bounds.X)
            .Select(node => node.Bounds)
            .ToArray();
        if (obstacles.Length == 0 || obstacles[0] != openLocation.Bounds)
        {
            return null;
        }

        return new TitlebarSnapshot(openLocation.Bounds.X, obstacles, toolbar.Bounds);
    }

    private static bool Contains(RectD container, RectD child) =>
        child.Width > 0
        && child.Height > 0
        && child.X >= container.X
        && child.Y >= container.Y
        && child.Right <= container.Right
        && child.Bottom <= container.Bottom;

    private static RectD Expand(RectD bounds, double amount) => new(
        bounds.X - amount,
        bounds.Y - amount,
        bounds.Width + (2 * amount),
        bounds.Height + (2 * amount));
}
