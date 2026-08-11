namespace CodexUsageSidebar.Core;

public readonly record struct RectD(double X, double Y, double Width, double Height)
{
    public double Right => X + Width;
    public double Bottom => Y + Height;

    public bool IntersectsHorizontally(RectD other) => X < other.Right && Right > other.X;
}

public enum PlacementSurface { Content, RightToolbar }

public readonly record struct PlacementResult(PlacementSurface Surface, RectD Frame);

public static class PlacementResolver
{
    public static PlacementResult Resolve(
        RectD window,
        double preferredAnchorTrailingEdge,
        double indicatorWidth,
        double gap,
        IReadOnlyList<RectD> obstacles)
    {
        var minimumContentX = window.X + (window.Width / 2);
        var candidateX = Math.Min(preferredAnchorTrailingEdge - gap - indicatorWidth, window.Right - indicatorWidth - gap);

        while (candidateX >= minimumContentX)
        {
            var candidate = new RectD(candidateX, window.Y + 4, indicatorWidth, 40);
            var collision = obstacles
                .Where(candidate.IntersectsHorizontally)
                .OrderBy(x => x.X)
                .FirstOrDefault();
            if (collision.Width <= 0)
            {
                return new PlacementResult(PlacementSurface.Content, candidate);
            }
            candidateX = collision.X - gap - indicatorWidth;
        }

        return new PlacementResult(
            PlacementSurface.RightToolbar,
            new RectD(window.Right - indicatorWidth - 16, window.Y + 4, indicatorWidth, 40));
    }
}
