using System.Text.Json;
using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Windows.Tests;

[TestClass]
public sealed class CodexTitlebarSelectorTests
{
    [TestMethod]
    public void ResolvesTheMeasuredCaptionBoundaryForTheValidatedBuild()
    {
        var fixture = LoadFixture();

        var result = CodexTitlebarSelector.TryResolve(
            fixture.BuildIdentity,
            fixture.DpiScale,
            fixture.HostBounds,
            fixture.Nodes);

        Assert.IsNotNull(result);
        Assert.AreEqual(fixture.Expected.PreferredAnchorTrailingEdge, result.PreferredAnchorTrailingEdge, 0.001);
        Assert.AreEqual(fixture.Expected.ObstacleCount, result.Obstacles.Count);
    }

    [TestMethod]
    public void RejectsUnknownBuilds()
    {
        var fixture = LoadFixture();

        var result = CodexTitlebarSelector.TryResolve(
            "151.0.7922.77",
            fixture.DpiScale,
            fixture.HostBounds,
            fixture.Nodes);

        Assert.IsNull(result);
    }

    [TestMethod]
    public void RejectsIncompleteCaptionControls()
    {
        var fixture = LoadFixture();
        var incomplete = fixture.Nodes.Where(node => node.AutomationId != "view_4").ToArray();

        var result = CodexTitlebarSelector.TryResolve(
            fixture.BuildIdentity,
            fixture.DpiScale,
            fixture.HostBounds,
            incomplete);

        Assert.IsNull(result);
    }

    [TestMethod]
    public void RejectsCaptionGeometryOutsideTheHostWindow()
    {
        var fixture = LoadFixture();
        var invalid = fixture.Nodes.Select(node =>
            node.ClassName == "ChromeNodeCaptionButtonContainer"
                ? node with { Bounds = node.Bounds with { X = 10_000 } }
                : node).ToArray();

        var result = CodexTitlebarSelector.TryResolve(
            fixture.BuildIdentity,
            fixture.DpiScale,
            fixture.HostBounds,
            invalid);

        Assert.IsNull(result);
    }

    [TestMethod]
    public void RejectsCaptionButtonsOutsideTheirMeasuredContainer()
    {
        var fixture = LoadFixture();
        var invalid = fixture.Nodes.Select(node =>
            node.AutomationId == "view_4"
                ? node with { Bounds = node.Bounds with { X = 100 } }
                : node).ToArray();

        var result = CodexTitlebarSelector.TryResolve(
            fixture.BuildIdentity,
            fixture.DpiScale,
            fixture.HostBounds,
            invalid);

        Assert.IsNull(result);
    }

    [TestMethod]
    public void PreservesPhysicalCoordinatesOnANegativeOriginHighDpiMonitor()
    {
        var fixture = LoadFixture();
        const double offset = -4000;
        var host = fixture.HostBounds with { X = fixture.HostBounds.X + offset };
        var nodes = fixture.Nodes.Select(node => node with
        {
            Bounds = node.Bounds with { X = node.Bounds.X + offset },
        }).ToArray();

        var result = CodexTitlebarSelector.TryResolve(
            fixture.BuildIdentity,
            fixture.DpiScale,
            host,
            nodes);

        Assert.IsNotNull(result);
        Assert.AreEqual(
            fixture.Expected.PreferredAnchorTrailingEdge + offset,
            result.PreferredAnchorTrailingEdge,
            0.001);
    }

    private static SelectorFixture LoadFixture() => JsonSerializer.Deserialize<SelectorFixture>(
        File.ReadAllText(Path.Combine(
            AppContext.BaseDirectory,
            "contracts",
            "uia",
            "windows-codex-151.0.7922.76-default-200.json")),
        new JsonSerializerOptions { PropertyNameCaseInsensitive = true })!;

    private sealed record SelectorFixture(
        string BuildIdentity,
        double DpiScale,
        RectD HostBounds,
        IReadOnlyList<UiaStructureNode> Nodes,
        ExpectedFixture Expected);

    private sealed record ExpectedFixture(
        double PreferredAnchorTrailingEdge,
        int ObstacleCount);
}
