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
    private const string TitleGroupClassMarker = "text-md flex min-w-0 items-center";
    private const string TitleTextClassMarker = "max-w-[320px] min-w-0 truncate";
    private const string RightPaneClassMarker = "relative z-[41] h-full";
    private const string RightPaneShrinkClassMarker = "min-w-0 shrink-0 overflow-visible";
    private const string RightToolbarClassMarker = "hide-scrollbar flex h-full min-w-0 flex-1";
    private const string RightToolbarOverflowMarker = "overflow-x-auto overflow-y-hidden";
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
        var titleGroups = nodes.Where(node =>
            node.ControlType == GroupControlType
            && node.Depth == contentGroup.Depth + 1
            && node.ClassName.Contains(TitleGroupClassMarker, StringComparison.Ordinal)
            && Contains(contentGroup.Bounds, node.Bounds)).ToArray();
        var titleBounds = titleGroups.Length switch
        {
            1 => TryResolveTitleChildren(nodes, titleGroups[0].Bounds, titleGroups[0].Depth + 1, dpiScale),
            0 => TryResolveTitleChildren(nodes, contentGroup.Bounds, contentGroup.Depth + 1, dpiScale),
            _ => null,
        };
        if (titleBounds is null)
        {
            return null;
        }
        var openLocationButtons = nodes.Where(node =>
            node.ControlType == ButtonControlType
            && node.Depth == contentGroup.Depth + 1
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

        var rightToolbarBounds = default(RectD);
        IReadOnlyList<RectD> rightObstacles = Array.Empty<RectD>();
        var rightPanes = nodes.Where(node =>
            node.ControlType == GroupControlType
            && node.ClassName.Contains(RightPaneClassMarker, StringComparison.Ordinal)
            && node.ClassName.Contains(RightPaneShrinkClassMarker, StringComparison.Ordinal)
            && Contains(hostBounds, node.Bounds)).ToArray();
        if (rightPanes.Length > 1)
        {
            return null;
        }
        if (rightPanes.Length == 1)
        {
            var rightPane = rightPanes[0];
            var rightToolbars = nodes.Where(node =>
                node.ControlType == GroupControlType
                && node.Depth == rightPane.Depth + 3
                && node.ClassName.Contains(RightToolbarClassMarker, StringComparison.Ordinal)
                && node.ClassName.Contains(RightToolbarOverflowMarker, StringComparison.Ordinal)
                && Contains(rightPane.Bounds, node.Bounds)
                && Contains(toolbar.Bounds, node.Bounds)).ToArray();
            if (rightToolbars.Length != 1)
            {
                return null;
            }
            var rightToolbar = rightToolbars[0];
            var alignedButtons = nodes.Where(node =>
                node.ControlType == ButtonControlType
                && node.Depth == rightToolbar.Depth
                && node.ClassName.Contains("h-token-button-composer", StringComparison.Ordinal)
                && node.ClassName.Contains("aspect-square", StringComparison.Ordinal)
                && Contains(rightPane.Bounds, node.Bounds)
                && Math.Abs(node.Bounds.Y - openLocation.Bounds.Y) <= 2 * dpiScale
                && Math.Abs(node.Bounds.Height - openLocation.Bounds.Height) <= 2 * dpiScale
                && node.Bounds.X >= rightToolbar.Bounds.Right - (2 * dpiScale)).ToArray();
            if (alignedButtons.Length != 1)
            {
                return null;
            }
            rightToolbarBounds = rightToolbar.Bounds;
            rightObstacles = [alignedButtons[0].Bounds];
        }

        return new TitlebarSnapshot(
            openLocation.Bounds.X,
            obstacles,
            toolbar.Bounds,
            openLocation.Bounds,
            titleBounds.Value,
            rightToolbarBounds,
            rightObstacles);
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

    private static RectD Union(params RectD[] bounds)
    {
        var left = bounds.Min(item => item.X);
        var top = bounds.Min(item => item.Y);
        var right = bounds.Max(item => item.Right);
        var bottom = bounds.Max(item => item.Bottom);
        return new RectD(left, top, right - left, bottom - top);
    }

    private static RectD? TryResolveTitleChildren(
        IReadOnlyList<UiaStructureNode> nodes,
        RectD parentBounds,
        int childDepth,
        double dpiScale)
    {
        var expandedParent = Expand(parentBounds, 2 * dpiScale);
        var titleTexts = nodes.Where(node =>
            node.ControlType == GroupControlType
            && node.Depth == childDepth
            && node.ClassName.Contains(TitleTextClassMarker, StringComparison.Ordinal)
            && Contains(expandedParent, node.Bounds)).ToArray();
        if (titleTexts.Length != 1)
        {
            return null;
        }
        var titleText = titleTexts[0];
        var titleLeading = nodes.Where(node =>
            node.ControlType == ButtonControlType
            && node.Depth == childDepth
            && node.ClassName.Contains(ComposerButtonClassMarker, StringComparison.Ordinal)
            && node.ClassName.Contains("aspect-square", StringComparison.Ordinal)
            && node.Bounds.Right <= titleText.Bounds.X
            && titleText.Bounds.X - node.Bounds.Right <= 4 * dpiScale
            && Contains(expandedParent, node.Bounds)).ToArray();
        var titleActions = nodes.Where(node =>
            node.ControlType == ButtonControlType
            && node.Depth == childDepth
            && node.ClassName.Contains("rounded-full", StringComparison.Ordinal)
            && node.ClassName.Contains("cursor-interaction", StringComparison.Ordinal)
            && !node.ClassName.Contains(ComposerButtonClassMarker, StringComparison.Ordinal)
            && node.Bounds.X >= titleText.Bounds.Right - dpiScale
            && node.Bounds.X - titleText.Bounds.Right <= 2 * dpiScale
            && Contains(expandedParent, node.Bounds)).ToArray();
        if (titleLeading.Length != 1 || titleActions.Length != 1)
        {
            return null;
        }
        if (titleLeading[0].Bounds.Right > titleTexts[0].Bounds.Right
            || titleText.Bounds.Right > titleActions[0].Bounds.Right)
        {
            return null;
        }
        return Union(titleLeading[0].Bounds, titleText.Bounds, titleActions[0].Bounds);
    }
}
