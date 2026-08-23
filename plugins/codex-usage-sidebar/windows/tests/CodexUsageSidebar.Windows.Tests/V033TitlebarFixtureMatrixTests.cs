using System.Text.Json;
using System.Text.Json.Serialization;
using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Windows.Tests;

[TestClass]
public sealed class V033TitlebarFixtureMatrixTests
{
    [TestMethod]
    public async Task RawLocalizedUiaNamesResolveThroughTheScannerAtEveryRecordedDpi()
    {
        var matrix = LoadMatrix();
        foreach (var structure in matrix.Structures)
        {
            var source = LoadSourceFixture(structure.SourceFixture);
            foreach (var label in structure.SemanticLabels)
            foreach (var dpiCase in structure.DpiCases)
            {
                var host = ScaleHost(source, dpiCase.DpiScale);
                var scanner = new ValidatedUiaTitlebarScanner(
                    SelectorProfileCatalog.Default,
                    (_, _) => ValueTask.FromResult<IReadOnlyList<UiaScanningObservation>>(
                        RawObservations(source.Nodes, label.Value, source.DpiScale, dpiCase.DpiScale)));

                var result = await scanner.ScanAsync(host, CancellationToken.None);

                AssertGeometry(dpiCase.ExpectedGeometry, result, $"{structure.Id} {label.Key} {dpiCase.DpiScale:P0}");
                Assert.IsNotNull(PlacementResolver.ResolveResponsive(
                    result.ToolbarBounds,
                    result.OpenLocationBounds,
                    result.TitleBounds,
                    OverlayVisualMetrics.IndicatorWidthForHeight(result.OpenLocationBounds.Height / dpiCase.DpiScale) * dpiCase.DpiScale,
                    0.5 * dpiCase.DpiScale,
                    result.Obstacles,
                    result.RightToolbarBounds,
                    result.RightObstacles,
                    0), $"{structure.Id} {label.Key} {dpiCase.DpiScale:P0} must place the selector result.");
            }
        }
    }

    [TestMethod]
    public async Task EveryUnrecognizedMatrixCaseShowsSafeDockThroughTheCoordinator()
    {
        var matrix = LoadMatrix();
        var observedAt = DateTimeOffset.UnixEpoch;
        foreach (var structure in matrix.Structures)
        {
            var source = LoadSourceFixture(structure.SourceFixture);
            var fallback = structure.UnrecognizedFallback;
            var host = new HostWindowSnapshot(new IntPtr(42), fallback.HostBounds, true, fallback.DpiScale,
                structure.BuildIdentity, fallback.WorkArea, fallback.CaptionBounds);
            var scanner = new ValidatedUiaTitlebarScanner(
                SelectorProfileCatalog.Default,
                (_, _) => ValueTask.FromResult<IReadOnlyList<UiaScanningObservation>>(RawObservations(
                    source.Nodes.Select(node => node with
                    {
                        ClassName = node.ClassName.Replace(structure.UnrecognizedMarker, "unrecognized-marker", StringComparison.Ordinal),
                    }).ToArray(), structure.SemanticLabels["en"], source.DpiScale, fallback.DpiScale)));
            var overlay = new RecordingOverlay();
            var coordinator = new WindowsHostCoordinator(new StubLocator(host), scanner, overlay, () => observedAt);

            await coordinator.ReconcileAsync(Snapshot(), CancellationToken.None);
            observedAt = observedAt.AddMilliseconds(500);
            await coordinator.ReconcileAsync(Snapshot(), CancellationToken.None);
            observedAt = observedAt.AddMilliseconds(500);
            var state = await coordinator.ReconcileAsync(Snapshot(), CancellationToken.None);

            Assert.AreEqual(HostRuntimeState.Visible, state, structure.Id);
            Assert.AreEqual(SafeDockPlacement.Fallback, coordinator.LastCompatibilityDecision?.Placement, structure.Id);
            Assert.AreEqual(CompatibilityFailureCode.UiaUnavailable, coordinator.LastCompatibilityDecision?.FailureCode, structure.Id);
            Assert.AreEqual(PlacementMode.SafeDock, overlay.LastPresentation?.Mode, structure.Id);
            Assert.AreEqual(fallback.ExpectedFrame, overlay.LastPresentation?.Placement.Frame, structure.Id);
            Assert.AreEqual(host.Bounds, overlay.LastPresentation?.SafeDockRequest?.HostBounds, structure.Id);
            Assert.AreEqual(host.WorkArea, overlay.LastPresentation?.SafeDockRequest?.WorkArea, structure.Id);
            Assert.AreEqual(host.CaptionBounds, overlay.LastPresentation?.SafeDockRequest?.CaptionBounds, structure.Id);
        }
    }

    private static void AssertGeometry(ExpectedGeometry expected, TitlebarSnapshot actual, string message)
    {
        Assert.AreEqual(expected.ToolbarBounds, actual.ToolbarBounds, message);
        Assert.AreEqual(expected.OpenLocationBounds, actual.OpenLocationBounds, message);
        Assert.AreEqual(expected.TitleBounds, actual.TitleBounds, message);
        Assert.AreEqual(expected.RightToolbarBounds, actual.RightToolbarBounds, message);
        CollectionAssert.AreEqual(expected.Obstacles.ToArray(), actual.Obstacles.ToArray(), message);
        CollectionAssert.AreEqual(expected.RightObstacles.ToArray(), actual.RightObstacles.ToArray(), message);
    }

    private static HostWindowSnapshot ScaleHost(SourceFixture source, double dpiScale)
    {
        var scale = dpiScale / source.DpiScale;
        return new HostWindowSnapshot(new IntPtr(42), Scale(source.HostBounds, scale), true, dpiScale, source.BuildIdentity);
    }

    private static IReadOnlyList<UiaScanningObservation> RawObservations(IReadOnlyList<UiaStructureNode> nodes,
        string openLocationName, double sourceDpiScale, double dpiScale)
    {
        var scale = dpiScale / sourceDpiScale;
        return nodes.Select(node => new UiaScanningObservation(node.Depth, node.ControlType, node.AutomationId,
            node.ClassName, Scale(node.Bounds, scale), node.ClassName.Contains("rounded-e-none", StringComparison.Ordinal)
                ? openLocationName : string.Empty)).ToArray();
    }

    private static RectD Scale(RectD bounds, double scale) => new(bounds.X * scale, bounds.Y * scale, bounds.Width * scale, bounds.Height * scale);
    private static MatrixFixture LoadMatrix() => JsonSerializer.Deserialize<MatrixFixture>(File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "contracts", "uia", "windows-v033-titlebar-matrix.json")), Options)!;
    private static SourceFixture LoadSourceFixture(string fileName) => JsonSerializer.Deserialize<SourceFixture>(File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "contracts", "uia", fileName)), Options)!;
    private static JsonSerializerOptions Options { get; } = new() { PropertyNameCaseInsensitive = true, Converters = { new JsonStringEnumConverter() } };
    private static AllowanceSnapshot Snapshot() => new(24, 76, DateTimeOffset.UnixEpoch, DateTimeOffset.UnixEpoch);

    private sealed class StubLocator(HostWindowSnapshot host) : IHostWindowLocator { public ValueTask<HostWindowSnapshot?> FindAsync(CancellationToken cancellationToken) => ValueTask.FromResult<HostWindowSnapshot?>(host); }
    private sealed class RecordingOverlay : IOverlaySurface { public OverlayPresentation? LastPresentation { get; private set; } public ValueTask ShowAsync(OverlayPresentation presentation, CancellationToken cancellationToken) { LastPresentation = presentation; return ValueTask.CompletedTask; } public ValueTask HideAsync(CancellationToken cancellationToken) { LastPresentation = null; return ValueTask.CompletedTask; } }
    private sealed record MatrixFixture(IReadOnlyList<MatrixStructure> Structures);
    private sealed record MatrixStructure(string Id, string SourceFixture, string BuildIdentity, IReadOnlyDictionary<string, string> SemanticLabels, IReadOnlyList<DpiCase> DpiCases, string UnrecognizedMarker, UnrecognizedFallback UnrecognizedFallback);
    private sealed record DpiCase(double DpiScale, ExpectedGeometry ExpectedGeometry);
    private sealed record UnrecognizedFallback(double DpiScale, RectD HostBounds, RectD WorkArea, RectD CaptionBounds, RectD ExpectedFrame);
    private sealed record ExpectedGeometry(RectD ToolbarBounds, RectD OpenLocationBounds, RectD TitleBounds, RectD RightToolbarBounds, IReadOnlyList<RectD> Obstacles, IReadOnlyList<RectD> RightObstacles);
    private sealed record SourceFixture(string BuildIdentity, double DpiScale, RectD HostBounds, IReadOnlyList<UiaStructureNode> Nodes);
}
