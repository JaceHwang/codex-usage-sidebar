using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Windows;

public static class OverlayDetailLayout
{
    public const double LogoSize = 28;
    public const double RowSeparatorHeight = 1;

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
