namespace CodexUsageSidebar.Windows;

public static class UiaTraversalBudget
{
    public const int ProductionMaximumNodes = 4_000;
    public const int ProductionMaximumDepth = 32;
    public const int DiagnosticMaximumNodes = 4_000;
    public const int DiagnosticMaximumDepth = 32;

    public static bool HasFiniteBounds(CodexUsageSidebar.Core.RectD bounds) =>
        double.IsFinite(bounds.X)
        && double.IsFinite(bounds.Y)
        && double.IsFinite(bounds.Width)
        && double.IsFinite(bounds.Height);
}
