#if WINDOWS
using System.Windows;
using System.Windows.Media;
using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Windows;

internal sealed class WpfQuotaProgressBar : FrameworkElement
{
    public static readonly DependencyProperty RemainingPercentProperty = DependencyProperty.Register(
        nameof(RemainingPercent),
        typeof(int),
        typeof(WpfQuotaProgressBar),
        new FrameworkPropertyMetadata(0, FrameworkPropertyMetadataOptions.AffectsRender));

    public int RemainingPercent
    {
        get => (int)GetValue(RemainingPercentProperty);
        set => SetValue(RemainingPercentProperty, value);
    }

    protected override void OnRender(DrawingContext drawingContext)
    {
        base.OnRender(drawingContext);
        var width = Math.Max(0, RenderSize.Width);
        var height = Math.Max(0, RenderSize.Height);
        if (width <= 0 || height <= 0) return;

        var radius = Math.Min(2, height / 2);
        var trackColor = SystemColors.GrayTextColor;
        var trackBrush = new SolidColorBrush(Color.FromArgb(
            32,
            trackColor.R,
            trackColor.G,
            trackColor.B));
        trackBrush.Freeze();
        var track = new Rect(0, 0, width, height);
        drawingContext.DrawRoundedRectangle(trackBrush, null, track, radius, radius);

        var geometry = QuotaProgressGeometry.Create(width, RemainingPercent);
        if (geometry.ClipWidth <= 0) return;
        var clip = new RectangleGeometry(
            new Rect(0, 0, geometry.ClipWidth, height),
            radius,
            radius);
        var spectrum = new LinearGradientBrush
        {
            StartPoint = new Point(0, 0.5),
            EndPoint = new Point(1, 0.5),
            MappingMode = BrushMappingMode.RelativeToBoundingBox,
        };
        foreach (var stop in QuotaProgressSpectrum.Stops)
        {
            spectrum.GradientStops.Add(new GradientStop(
                WpfQuotaColors.FromHsb(stop.Color),
                stop.Location));
        }
        spectrum.Freeze();

        drawingContext.PushClip(clip);
        drawingContext.DrawRoundedRectangle(spectrum, null, track, radius, radius);
        drawingContext.Pop();
    }
}

internal static class WpfQuotaColors
{
    internal static Color ForRemainingPercent(int remainingPercent) =>
        FromHsb(QuotaColorScale.ForRemainingPercent(remainingPercent));

    internal static Color FromHsb(HsbColor hsb)
    {
        var hue = (hsb.Hue - Math.Floor(hsb.Hue)) * 6;
        var chroma = hsb.Brightness * hsb.Saturation;
        var x = chroma * (1 - Math.Abs(hue % 2 - 1));
        var m = hsb.Brightness - chroma;
        var (red, green, blue) = hue switch
        {
            < 1 => (chroma, x, 0d),
            < 2 => (x, chroma, 0d),
            < 3 => (0d, chroma, x),
            < 4 => (0d, x, chroma),
            < 5 => (x, 0d, chroma),
            _ => (chroma, 0d, x),
        };
        return Color.FromRgb(ToByte(red + m), ToByte(green + m), ToByte(blue + m));
    }

    private static byte ToByte(double value) =>
        (byte)Math.Round(Math.Clamp(value, 0, 1) * 255, MidpointRounding.AwayFromZero);
}
#endif
