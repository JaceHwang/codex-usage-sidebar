using System.Text.Json;
using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Windows.Tests;

[TestClass]
public sealed class CodexTitlebarSelectorTests
{
    [TestMethod]
    public void ResolvesTheMeasuredOpenLocationBoundaryForTheValidatedBuild()
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
        Assert.AreEqual(fixture.Expected.ToolbarBounds, result.ToolbarBounds);
        Assert.AreEqual(fixture.Expected.OpenLocationBounds, result.OpenLocationBounds);
        Assert.AreEqual(fixture.Expected.TitleBounds, result.TitleBounds);
        Assert.AreEqual(fixture.Expected.RightToolbarBounds, result.RightToolbarBounds);
        Assert.AreEqual(fixture.Expected.RightObstacleCount, result.RightObstacles.Count);
    }

    [TestMethod]
    public void ResolvesTheValidatedNarrowRightToolbarWithoutUsingTheOuterCaption()
    {
        var fixture = LoadFixture("windows-codex-151.0.7922.76-narrow-200.json");

        var result = CodexTitlebarSelector.TryResolve(
            fixture.BuildIdentity,
            fixture.DpiScale,
            fixture.HostBounds,
            fixture.Nodes);

        Assert.IsNotNull(result);
        Assert.AreEqual(new RectD(1069, 88, 183, 56), result.OpenLocationBounds);
        Assert.AreEqual(new RectD(494, 88, 533, 56), result.TitleBounds);
        Assert.AreEqual(new RectD(1395, 70, 1461, 92), result.RightToolbarBounds);
        CollectionAssert.AreEqual(
            new[] { new RectD(2856, 88, 56, 56) },
            result.RightObstacles.ToArray());
        Assert.AreNotEqual(
            fixture.Nodes.Single(node => node.ClassName == "ChromeNodeCaptionButtonContainer").Bounds,
            result.RightToolbarBounds);
    }

    [TestMethod]
    public void RightToolbarDiscoveryOnlyStartsFromAlignedTrailingComposerButtons()
    {
        var openLocation = new RectD(1069, 88, 183, 56);
        var candidate = new UiaStructureNode(
            18,
            "ControlType.Button",
            "",
            "h-token-button-composer aspect-square shrink-0",
            new RectD(2856, 88, 56, 56),
            4);

        Assert.IsTrue(RightToolbarCandidatePolicy.IsCandidate(openLocation, candidate.Bounds, candidate.ControlType, candidate.ClassName, 2));
        Assert.IsFalse(RightToolbarCandidatePolicy.IsCandidate(openLocation, candidate.Bounds with { X = 1200 }, candidate.ControlType, candidate.ClassName, 2));
        Assert.IsFalse(RightToolbarCandidatePolicy.IsCandidate(openLocation, candidate.Bounds with { Y = 120 }, candidate.ControlType, candidate.ClassName, 2));
        Assert.IsFalse(RightToolbarCandidatePolicy.IsCandidate(openLocation, candidate.Bounds, candidate.ControlType, "h-token-button-composer", 2));
        Assert.IsFalse(RightToolbarCandidatePolicy.IsCandidate(openLocation, candidate.Bounds, "ControlType.Group", candidate.ClassName, 2));
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
    public void RejectsCaptionOnlyTreesInsteadOfUsingTheOuterWindowsTitlebar()
    {
        var fixture = LoadFixture();
        var captionOnly = fixture.Nodes.Where(node => node.Depth <= 4).ToArray();

        var result = CodexTitlebarSelector.TryResolve(
            fixture.BuildIdentity,
            fixture.DpiScale,
            fixture.HostBounds,
            captionOnly);

        Assert.IsNull(result);
    }

    [TestMethod]
    public void RejectsMissingAndAmbiguousOpenLocationControls()
    {
        var fixture = LoadFixture();
        var missing = fixture.Nodes.Select(node =>
            node.SemanticRole == UiaSemanticRoles.OpenLocation
                ? node with { SemanticRole = UiaSemanticRoles.None }
                : node).ToArray();
        var duplicate = fixture.Nodes.Concat([
            fixture.Nodes.Single(node => node.SemanticRole == UiaSemanticRoles.OpenLocation) with
            {
                Bounds = new RectD(1600, 88, 183, 56),
            },
        ]).ToArray();

        Assert.IsNull(CodexTitlebarSelector.TryResolve(
            fixture.BuildIdentity, fixture.DpiScale, fixture.HostBounds, missing));
        Assert.IsNull(CodexTitlebarSelector.TryResolve(
            fixture.BuildIdentity, fixture.DpiScale, fixture.HostBounds, duplicate));
    }

    [TestMethod]
    public void RejectsMissingAmbiguousAndOffHostRightToolbarStructures()
    {
        var fixture = LoadFixture("windows-codex-151.0.7922.76-narrow-200.json");
        var rightToolbar = fixture.Nodes.Single(node =>
            node.ClassName.Contains("hide-scrollbar flex h-full", StringComparison.Ordinal));
        var missing = fixture.Nodes.Where(node => node != rightToolbar).ToArray();
        var duplicate = fixture.Nodes.Append(rightToolbar with
        {
            Bounds = rightToolbar.Bounds with { X = rightToolbar.Bounds.X + 10 },
        }).ToArray();
        var offHost = fixture.Nodes.Select(node => node == rightToolbar
            ? node with { Bounds = node.Bounds with { X = 10_000 } }
            : node).ToArray();

        Assert.IsNull(CodexTitlebarSelector.TryResolve(
            fixture.BuildIdentity, fixture.DpiScale, fixture.HostBounds, missing));
        Assert.IsNull(CodexTitlebarSelector.TryResolve(
            fixture.BuildIdentity, fixture.DpiScale, fixture.HostBounds, duplicate));
        Assert.IsNull(CodexTitlebarSelector.TryResolve(
            fixture.BuildIdentity, fixture.DpiScale, fixture.HostBounds, offHost));
    }

    [TestMethod]
    public void RejectsMissingOrAmbiguousMeasuredTitleChildren()
    {
        var fixture = LoadFixture("windows-codex-151.0.7922.76-narrow-200.json");
        var titleChild = fixture.Nodes.Single(node =>
            node.Depth == 17
            && node.ControlType == "ControlType.Group"
            && node.ClassName.Contains("max-w-[320px]", StringComparison.Ordinal));
        var missing = fixture.Nodes.Where(node => node != titleChild).ToArray();
        var duplicate = fixture.Nodes.Append(titleChild with
        {
            Bounds = titleChild.Bounds with { X = titleChild.Bounds.X + 1 },
        }).ToArray();

        Assert.IsNull(CodexTitlebarSelector.TryResolve(
            fixture.BuildIdentity, fixture.DpiScale, fixture.HostBounds, missing));
        Assert.IsNull(CodexTitlebarSelector.TryResolve(
            fixture.BuildIdentity, fixture.DpiScale, fixture.HostBounds, duplicate));
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
    public void AcceptsTheMeasuredTwoPixelRestoreButtonOverlapInWindowedMode()
    {
        var fixture = LoadFixture();
        var windowed = fixture.Nodes.Select(node =>
            node.ClassName == "ChromeNodeCaptionButtonContainer"
                ? node with { Bounds = node.Bounds with { Height = 70 } }
                : node).ToArray();

        var result = CodexTitlebarSelector.TryResolve(
            fixture.BuildIdentity,
            fixture.DpiScale,
            fixture.HostBounds,
            windowed);

        Assert.IsNotNull(result);
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

    private static SelectorFixture LoadFixture(
        string name = "windows-codex-151.0.7922.76-default-200.json") =>
        JsonSerializer.Deserialize<SelectorFixture>(
        File.ReadAllText(Path.Combine(
            AppContext.BaseDirectory,
            "contracts",
            "uia",
            name)),
        new JsonSerializerOptions { PropertyNameCaseInsensitive = true })!;

    private sealed record SelectorFixture(
        string BuildIdentity,
        double DpiScale,
        RectD HostBounds,
        IReadOnlyList<UiaStructureNode> Nodes,
        ExpectedFixture Expected);

    private sealed record ExpectedFixture(
        double PreferredAnchorTrailingEdge,
        int ObstacleCount,
        RectD ToolbarBounds,
        RectD OpenLocationBounds,
        RectD TitleBounds,
        RectD RightToolbarBounds,
        int RightObstacleCount);
}
