namespace CodexUsageSidebar.Windows;

public static class OverlayVisualMetrics
{
    public const double IndicatorHeight = 28;
    public const double DetailWidth = 360;
    public const double HeaderTitleFontSize = 18;
    public const double HeaderTitleMaximumWidth = 190;
    public const double VersionBadgeFontSize = 9;
    public const double VersionBadgeHeight = 18;
    public const double RemainingPercentFontSize = 28;
    public const double DetailValueFontSize = 13;
    public const double CountdownDigitFontSize = 16;
    public const double CountdownUnitFontSize = 11;
    public const double ProgressTrackHeight = 4;

    public static double IndicatorWidthForTextAndHeight(double textWidth, double height) =>
        textWidth + (2 * IndicatorHorizontalPaddingForHeight(height));

    public static double IndicatorHorizontalPaddingForHeight(double height) =>
        height / 3;
}

public static class OverlayWindowPolicy
{
    private const uint NoActivate = 0x0010;
    private const uint ShowWindow = 0x0040;
    private const uint NoOwnerZOrder = 0x0200;

    public const uint PositionFlags = NoActivate | ShowWindow | NoOwnerZOrder;
}
