namespace CodexUsageSidebar.Windows;

public static class OverlayVisualMetrics
{
    public const double IndicatorWidth = 164;
    public const double IndicatorHeight = 46;
    public const double DetailWidth = 300;
    public const double HeaderTitleFontSize = 14;
    public const double HeaderTitleMaximumWidth = 145;
    public const double VersionBadgeFontSize = 8;
    public const double VersionBadgeHeight = 14;
    public const double RemainingPercentFontSize = 18;
    public const double DetailValueFontSize = 12;
    public const double CountdownDigitFontSize = 14;
    public const double CountdownUnitFontSize = 10;
    public const double ProgressTrackHeight = 4;
}

public static class OverlayWindowPolicy
{
    private const uint NoActivate = 0x0010;
    private const uint ShowWindow = 0x0040;
    private const uint NoOwnerZOrder = 0x0200;

    public const uint PositionFlags = NoActivate | ShowWindow | NoOwnerZOrder;
}
