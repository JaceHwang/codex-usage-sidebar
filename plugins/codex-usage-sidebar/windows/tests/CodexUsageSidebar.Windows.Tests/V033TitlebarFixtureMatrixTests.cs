using System.Text.Json;
using System.Text.Json.Serialization;
using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Windows.Tests;

[TestClass]
public sealed class V033TitlebarFixtureMatrixTests
{
    [TestMethod]
    public void SampledStructuresResolveAcrossDpiAndLocalizedSemanticLabels()
    {
        var matrix = LoadMatrix();

        Assert.AreEqual(3, matrix.Structures.Count);
        CollectionAssert.AreEquivalent(
            new[] { "wide", "narrow", "right-pane" },
            matrix.Structures.Select(structure => structure.Form).ToArray());
        foreach (var structure in matrix.Structures)
        {
            CollectionAssert.AreEquivalent(new[] { "en", "zh-CN" }, structure.SemanticLabels.Keys.ToArray());
            CollectionAssert.AreEquivalent(new[] { 1d, 1.25d, 1.5d, 2d }, structure.DpiScales.ToArray());

            var source = LoadSourceFixture(structure.SourceFixture);
            foreach (var semanticLabel in structure.SemanticLabels)
            {
                var classifiedRole = UiaSemanticRoleClassifier.Classify(semanticLabel.Value);
                Assert.AreEqual(UiaSemanticRoles.OpenLocation, classifiedRole, structure.Id);
                var semanticNodes = InjectOpenLocationSemanticRole(source.Nodes, classifiedRole);

                foreach (var dpiScale in structure.DpiScales)
                {
                    var transform = dpiScale / source.DpiScale;
                    var result = CodexTitlebarSelector.TryResolve(
                        structure.BuildIdentity,
                        dpiScale,
                        Scale(source.HostBounds, transform),
                        semanticNodes.Select(node => node with { Bounds = Scale(node.Bounds, transform) }).ToArray());

                    Assert.IsNotNull(result, $"{structure.Id} {semanticLabel.Key} at {dpiScale:P0} must resolve semantically.");
                    Assert.AreEqual(Scale(structure.Expected.Geometry.ToolbarBounds, transform), result.ToolbarBounds, structure.Id);
                    Assert.AreEqual(Scale(structure.Expected.Geometry.OpenLocationBounds, transform), result.OpenLocationBounds, structure.Id);
                    Assert.AreEqual(Scale(structure.Expected.Geometry.TitleBounds, transform), result.TitleBounds, structure.Id);
                    Assert.AreEqual(Scale(structure.Expected.Geometry.RightToolbarBounds, transform), result.RightToolbarBounds, structure.Id);
                    CollectionAssert.AreEqual(
                        structure.Expected.Geometry.Obstacles.Select(bounds => Scale(bounds, transform)).ToArray(),
                        result.Obstacles.ToArray(),
                        structure.Id);
                    CollectionAssert.AreEqual(
                        structure.Expected.Geometry.RightObstacles.Select(bounds => Scale(bounds, transform)).ToArray(),
                        result.RightObstacles.ToArray(),
                        structure.Id);
                    Assert.AreEqual(SemanticCompatibility.Valid, structure.Expected.Semantic);
                    Assert.AreEqual(ProfileCompatibility.Validated, structure.Expected.Profile);
                    Assert.AreEqual(SafeDockPlacement.Titlebar, structure.Expected.SafeDock);
                }
            }
        }
    }

    [TestMethod]
    public void EveryUnrecognizedMatrixCaseObtainsASafeDockWhenDataAndHostGeometryExist()
    {
        var matrix = LoadMatrix();
        var start = DateTimeOffset.UnixEpoch;

        foreach (var structure in matrix.Structures)
        {
            var source = LoadSourceFixture(structure.SourceFixture);
            var transform = 1.25d / source.DpiScale;
            var host = Scale(source.HostBounds, transform);
            var unrecognizedNodes = source.Nodes.Select(node => node with
            {
                ClassName = node.ClassName.Replace(structure.UnrecognizedMarker, "unrecognized-marker", StringComparison.Ordinal),
            }).ToArray();
            Assert.IsNull(CodexTitlebarSelector.TryResolve(
                structure.BuildIdentity,
                source.DpiScale,
                source.HostBounds,
                unrecognizedNodes), structure.Id);
            var unresolved = new CompatibilityDecision(
                SemanticCompatibility.Invalid,
                ProfileCompatibility.Invalid,
                SafeDockPlacement.None,
                CompatibilityFailureCode.MissingAnchor);
            var state = new CompatibilityStateMachine(SafeDockPreferences.Default);

            state.Transition(unresolved, hasLiveQuota: true, hasValidCodexHost: true, start);
            state.Transition(unresolved, hasLiveQuota: true, hasValidCodexHost: true, start.AddMilliseconds(500));
            var transition = state.Transition(unresolved, hasLiveQuota: true, hasValidCodexHost: true, start.AddSeconds(1));
            var placement = SafeDockPlacementResolver.Resolve(new SafeDockPlacementRequest(
                host,
                host,
                new RectD(host.X, host.Y, host.Width, 40 * 1.25d),
                1.25d,
                SafeDockPreferences.Default));

            Assert.AreEqual(SafeDockPlacement.Fallback, transition.Placement, structure.Id);
            Assert.IsTrue(transition.ShouldShowSafeDock, structure.Id);
            Assert.IsNotNull(placement.Frame, structure.Id);
            Assert.AreEqual(SafeDockNoPlacementReason.None, placement.NoPlacementReason, structure.Id);
        }
    }

    private static MatrixFixture LoadMatrix() => JsonSerializer.Deserialize<MatrixFixture>(
        File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "contracts", "uia", "windows-v033-titlebar-matrix.json")),
        Options)!;

    private static SourceFixture LoadSourceFixture(string fileName) => JsonSerializer.Deserialize<SourceFixture>(
        File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "contracts", "uia", fileName)),
        Options)!;

    private static JsonSerializerOptions Options { get; } = new()
    {
        PropertyNameCaseInsensitive = true,
        Converters = { new JsonStringEnumConverter() },
    };

    private static RectD Scale(RectD bounds, double scale) => new(
        bounds.X * scale,
        bounds.Y * scale,
        bounds.Width * scale,
        bounds.Height * scale);

    private static IReadOnlyList<UiaStructureNode> InjectOpenLocationSemanticRole(
        IReadOnlyList<UiaStructureNode> nodes,
        string semanticRole) => nodes.Select(node => node.SemanticRole == UiaSemanticRoles.OpenLocation
            ? node with { SemanticRole = semanticRole }
            : node).ToArray();

    private sealed record MatrixFixture(IReadOnlyList<MatrixStructure> Structures);
    private sealed record MatrixStructure(
        string Id,
        string SourceFixture,
        string BuildIdentity,
        string Form,
        IReadOnlyDictionary<string, string> SemanticLabels,
        IReadOnlyList<double> DpiScales,
        string UnrecognizedMarker,
        ExpectedOutcome Expected);
    private sealed record ExpectedOutcome(
        SemanticCompatibility Semantic,
        ProfileCompatibility Profile,
        SafeDockPlacement SafeDock,
        ExpectedGeometry Geometry);
    private sealed record ExpectedGeometry(
        RectD ToolbarBounds,
        RectD OpenLocationBounds,
        RectD TitleBounds,
        RectD RightToolbarBounds,
        IReadOnlyList<RectD> Obstacles,
        IReadOnlyList<RectD> RightObstacles);
    private sealed record SourceFixture(double DpiScale, RectD HostBounds, IReadOnlyList<UiaStructureNode> Nodes);
}
