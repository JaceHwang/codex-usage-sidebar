using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Windows;

public static class OverlayDetailLayout
{
    public const double LogoSize = 28;
    public const double RowSeparatorHeight = 1;
    public const int FullWidthSectionSeparatorCount = 2;
    public const double SectionSeparatorHeight = 1;
    public const double SectionSeparatorHorizontalMargin = 0;

    public static double LeftForIndicator(RectD indicatorFrame, RectD workArea, double detailWidth)
    {
        if (!double.IsFinite(detailWidth) || detailWidth <= 0)
        {
            return workArea.X;
        }

        var maximumLeft = Math.Max(workArea.X, workArea.Right - detailWidth);
        return Math.Clamp(indicatorFrame.X, workArea.X, maximumLeft);
    }
}
