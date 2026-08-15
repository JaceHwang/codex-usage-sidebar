using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Core.Tests;

[TestClass]
public sealed class QuotaProgressSpectrumTests
{
    [TestMethod]
    public void UsesTheMacOsCriticalRedRedOrangeGreenStopPositions()
    {
        var stops = QuotaProgressSpectrum.Stops;

        CollectionAssert.AreEqual(
            new[] { 0d, 0.10d, 0.49d, 1d },
            stops.Select(stop => stop.Location).ToArray());
        CollectionAssert.AreEqual(
            new[]
            {
                new HsbColor(0, 0.96, 0.76),
                new HsbColor(0, 0.86, 1),
                new HsbColor(0.078, 0.96, 1),
                new HsbColor(0.36, 0.78, 0.82),
            },
            stops.Select(stop => stop.Color).ToArray());
    }

    [DataTestMethod]
    [DataRow(-1, 0d)]
    [DataRow(0, 0d)]
    [DataRow(10, 0.10d)]
    [DataRow(41, 0.41d)]
    [DataRow(49, 0.49d)]
    [DataRow(100, 1d)]
    [DataRow(101, 1d)]
    public void ClipsTheFullSpectrumAtTheRemainingFraction(int remainingPercent, double expected)
    {
        Assert.AreEqual(expected, QuotaProgressSpectrum.ClipFraction(remainingPercent), 0.0001);
    }

    [TestMethod]
    public void KeepsTheGradientAtFullTrackWidthWhenOnlyFortyOnePercentRemains()
    {
        var geometry = QuotaProgressGeometry.Create(trackWidth: 276, remainingPercent: 41);

        Assert.AreEqual(276, geometry.TrackWidth, 0.001);
        Assert.AreEqual(276, geometry.SpectrumWidth, 0.001);
        Assert.AreEqual(113.16, geometry.ClipWidth, 0.001);
    }
}
