namespace CodexUsageSidebar.Core;

public enum DisplayLanguage
{
    SimplifiedChinese,
    TraditionalChinese,
    English,
}

public static class LanguageResolver
{
    public static DisplayLanguage Resolve(string? localeIdentifier)
    {
        var normalized = (localeIdentifier ?? string.Empty).Replace('_', '-').ToLowerInvariant();
        if (!normalized.StartsWith("zh", StringComparison.Ordinal))
        {
            return DisplayLanguage.English;
        }
        return normalized.Contains("hant", StringComparison.Ordinal)
            || normalized.Contains("-tw", StringComparison.Ordinal)
            || normalized.Contains("-hk", StringComparison.Ordinal)
            || normalized.Contains("-mo", StringComparison.Ordinal)
                ? DisplayLanguage.TraditionalChinese
                : DisplayLanguage.SimplifiedChinese;
    }
}

public readonly record struct RelativeIntervalSegment(string Text, bool IsEmphasized);

public static class RelativeIntervalFormatter
{
    public static IReadOnlyList<RelativeIntervalSegment> Format(TimeSpan interval, DisplayLanguage language)
    {
        var value = interval < TimeSpan.Zero ? TimeSpan.Zero : interval;
        var totalHours = (int)Math.Floor(value.TotalHours);
        var days = totalHours / 24;
        var hours = totalHours % 24;
        var dayUnit = language switch
        {
            DisplayLanguage.SimplifiedChinese => "天",
            DisplayLanguage.TraditionalChinese => "天",
            _ => "d",
        };
        var hourUnit = language switch
        {
            DisplayLanguage.SimplifiedChinese => "小时",
            DisplayLanguage.TraditionalChinese => "小時",
            _ => "h",
        };
        return new[]
        {
            new RelativeIntervalSegment(days.ToString(System.Globalization.CultureInfo.InvariantCulture), true),
            new RelativeIntervalSegment(dayUnit, false),
            new RelativeIntervalSegment(hours.ToString(System.Globalization.CultureInfo.InvariantCulture), true),
            new RelativeIntervalSegment(hourUnit, false),
        };
    }
}

public readonly record struct HsbColor(double Hue, double Saturation, double Brightness);

public static class QuotaColorScale
{
    private static readonly HsbColor Green = new(0.36, 0.78, 0.82);
    private static readonly HsbColor Orange = new(0.078, 0.96, 1);
    private static readonly HsbColor Red = new(0, 0.86, 1);
    private static readonly HsbColor CriticalRed = new(0, 0.96, 0.76);

    public static HsbColor ForRemainingPercent(int remainingPercent)
    {
        var value = Math.Clamp(remainingPercent, 0, 100);
        if (value >= 49) return Interpolate(Orange, Green, (value - 49d) / 51d);
        if (value >= 10) return Interpolate(Red, Orange, (value - 10d) / 39d);
        return Interpolate(CriticalRed, Red, value / 10d);
    }

    private static HsbColor Interpolate(HsbColor start, HsbColor end, double amount)
    {
        var value = Math.Clamp(amount, 0, 1);
        return new HsbColor(
            start.Hue + ((end.Hue - start.Hue) * value),
            start.Saturation + ((end.Saturation - start.Saturation) * value),
            start.Brightness + ((end.Brightness - start.Brightness) * value));
    }
}

public static class IndicatorHitTestPolicy
{
    public static byte BackgroundAlpha(bool highlighted) => highlighted ? (byte)18 : (byte)1;
}

public readonly record struct DetailInteractionState(bool IsPinned, bool IsPointerInside, bool SuppressHoverUntilExit)
{
    public static DetailInteractionState Initial => new(false, false, false);
    public bool ShouldShowDetail => IsPinned || (IsPointerInside && !SuppressHoverUntilExit);

    public DetailInteractionState PointerChanged(bool inside) =>
        this with { IsPointerInside = inside, SuppressHoverUntilExit = inside && SuppressHoverUntilExit };

    public DetailInteractionState TogglePinned(bool pointerInside) => IsPinned
        ? new DetailInteractionState(false, pointerInside, pointerInside)
        : new DetailInteractionState(true, pointerInside, false);
}

public enum SnapshotFreshness { Fresh, Dimmed, Hidden }

public static class RefreshPolicy
{
    public static TimeSpan Interval(bool isHostForeground) => TimeSpan.FromSeconds(isHostForeground ? 1 : 5);

    public static SnapshotFreshness Freshness(DateTimeOffset receivedAt, DateTimeOffset now)
    {
        var age = now - receivedAt;
        if (age >= TimeSpan.FromSeconds(300)) return SnapshotFreshness.Hidden;
        if (age >= TimeSpan.FromSeconds(120)) return SnapshotFreshness.Dimmed;
        return SnapshotFreshness.Fresh;
    }
}
