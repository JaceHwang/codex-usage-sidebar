namespace CodexUsageSidebar.Core;

public readonly record struct QuotaSpectrumStop(double Location, HsbColor Color);

public static class QuotaProgressSpectrum
{
    public static IReadOnlyList<QuotaSpectrumStop> Stops { get; } =
    [
        new(0, QuotaColorScale.ForRemainingPercent(0)),
        new(0.10, QuotaColorScale.ForRemainingPercent(10)),
        new(0.49, QuotaColorScale.ForRemainingPercent(49)),
        new(1, QuotaColorScale.ForRemainingPercent(100)),
    ];

    public static double ClipFraction(int remainingPercent) =>
        Math.Clamp(remainingPercent, 0, 100) / 100d;
}

public readonly record struct QuotaProgressGeometry(
    double TrackWidth,
    double SpectrumWidth,
    double ClipWidth)
{
    public static QuotaProgressGeometry Create(double trackWidth, int remainingPercent)
    {
        if (!double.IsFinite(trackWidth) || trackWidth < 0)
        {
            throw new ArgumentOutOfRangeException(nameof(trackWidth));
        }
        return new QuotaProgressGeometry(
            trackWidth,
            trackWidth,
            trackWidth * QuotaProgressSpectrum.ClipFraction(remainingPercent));
    }
}
