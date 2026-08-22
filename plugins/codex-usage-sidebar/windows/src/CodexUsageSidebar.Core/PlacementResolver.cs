namespace CodexUsageSidebar.Core;

public readonly record struct RectD(double X, double Y, double Width, double Height)
{
    public double Right => X + Width;
    public double Bottom => Y + Height;
}

public enum PlacementSurface { Content, RightToolbar }

public readonly record struct PlacementResult(PlacementSurface Surface, RectD Frame);

public static class PlacementResolver
{
    public static PlacementResult? ResolveResponsive(
        RectD toolbarBounds,
        RectD openLocationBounds,
        RectD titleBounds,
        double indicatorWidth,
        double gap,
        IReadOnlyList<RectD> localObstacles,
        RectD rightToolbarBounds,
        IReadOnlyList<RectD> rightObstacles)
    {
        if (!IsUsable(toolbarBounds)
            || !IsUsable(openLocationBounds)
            || !IsUsable(titleBounds)
            || !double.IsFinite(indicatorWidth)
            || indicatorWidth <= 0
            || !double.IsFinite(gap)
            || gap < 0
            || !Contains(toolbarBounds, openLocationBounds)
            || !Contains(toolbarBounds, titleBounds))
        {
            return null;
        }

        // Keep the indicator in the middle titlebar whenever the title has
        // enough room. The right page is only the overflow fallback when the
        // middle titlebar cannot contain a collision-free frame.
        var local = new RectD(
            openLocationBounds.X - gap - indicatorWidth,
            openLocationBounds.Y,
            indicatorWidth,
            openLocationBounds.Height);
        if (Contains(toolbarBounds, local)
            && local.X >= titleBounds.Right + gap
            && !IntersectsAny(local, localObstacles))
        {
            return new PlacementResult(PlacementSurface.Content, local);
        }

        if (IsUsable(rightToolbarBounds)
            && rightObstacles.Count > 0
            && Contains(toolbarBounds, rightToolbarBounds)
            && rightObstacles.All(IsUsable))
        {
            var trailingObstacle = rightObstacles.OrderBy(obstacle => obstacle.X).First();
            var fallback = new RectD(
                trailingObstacle.X - gap - indicatorWidth,
                openLocationBounds.Y,
                indicatorWidth,
                openLocationBounds.Height);
            if (Contains(rightToolbarBounds, fallback)
                && !IntersectsAny(fallback, rightObstacles))
            {
                return new PlacementResult(PlacementSurface.RightToolbar, fallback);
            }
        }
        return null;
    }

    private static bool IntersectsAny(RectD candidate, IReadOnlyList<RectD> obstacles) =>
        obstacles.Any(obstacle => IsUsable(obstacle)
            && candidate.X < obstacle.Right
            && candidate.Right > obstacle.X
            && candidate.Y < obstacle.Bottom
            && candidate.Bottom > obstacle.Y);

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
