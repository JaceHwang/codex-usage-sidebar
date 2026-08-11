using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Windows.Tests;

[TestClass]
public sealed class HostCoordinatorTests
{
    [TestMethod]
    public async Task HidesOverlayWhenCodexWindowDoesNotExist()
    {
        var overlay = new RecordingOverlay();
        var coordinator = new WindowsHostCoordinator(
            new StubLocator(null), new StubScanner(), overlay);

        var result = await coordinator.ReconcileAsync(Snapshot(), CancellationToken.None);

        Assert.AreEqual(HostRuntimeState.WaitingForCodex, result);
        Assert.AreEqual(1, overlay.HideCount);
        Assert.IsNull(overlay.LastPresentation);
    }

    [TestMethod]
    public async Task ShowsSnapshotInCollisionFreeContentSlot()
    {
        var window = new HostWindowSnapshot(
            new IntPtr(42), new RectD(0, 0, 2048, 1100), true, 2, "codex-build-a");
        var scanner = new StubScanner(new TitlebarSnapshot(1500, new[]
        {
            new RectD(1516, 1052, 116, 36),
            new RectD(1900, 1052, 132, 36),
        }));
        var overlay = new RecordingOverlay();
        var coordinator = new WindowsHostCoordinator(new StubLocator(window), scanner, overlay);

        var result = await coordinator.ReconcileAsync(Snapshot(), CancellationToken.None);

        Assert.AreEqual(HostRuntimeState.Visible, result);
        Assert.AreEqual(PlacementSurface.Content, overlay.LastPresentation?.Placement.Surface);
        Assert.AreEqual(1284, overlay.LastPresentation?.Placement.Frame.X);
        Assert.AreEqual(76, overlay.LastPresentation?.Snapshot.RemainingPercent);
    }

    [TestMethod]
    public async Task HostBuildChangeInvalidatesScannerBeforeNextSnapshot()
    {
        var locator = new SequencedLocator(
            Window("codex-build-a"), Window("codex-build-b"));
        var scanner = new StubScanner(new TitlebarSnapshot(1000, Array.Empty<RectD>()));
        var coordinator = new WindowsHostCoordinator(locator, scanner, new RecordingOverlay());

        await coordinator.ReconcileAsync(Snapshot(), CancellationToken.None);
        await coordinator.ReconcileAsync(Snapshot(), CancellationToken.None);

        Assert.AreEqual(1, scanner.InvalidateCount);
    }

    [TestMethod]
    public async Task UnverifiedUiaTreeHidesOverlayAndReportsDeviceValidationRequirement()
    {
        var overlay = new RecordingOverlay();
        var coordinator = new WindowsHostCoordinator(
            new StubLocator(Window("unknown-build")),
            new RejectingScanner(),
            overlay);

        var result = await coordinator.ReconcileAsync(Snapshot(), CancellationToken.None);

        Assert.AreEqual(HostRuntimeState.DeviceValidationRequired, result);
        Assert.AreEqual(1, overlay.HideCount);
    }

    [TestMethod]
    public void AppServerLaunchPlanUsesFixedArgumentsAndIsolatedCodexHome()
    {
        var plan = AppServerLaunchPlan.Create(
            @"C:\Program Files\Codex\codex.exe",
            @"C:\Users\fixture\AppData\Local\CodexUsageSidebar\CodexHome");

        CollectionAssert.AreEqual(new[] { "app-server", "--stdio" }, plan.Arguments.ToArray());
        Assert.AreEqual(@"C:\Users\fixture\AppData\Local\CodexUsageSidebar\CodexHome", plan.Environment["CODEX_HOME"]);
        Assert.ThrowsException<ArgumentException>(() => AppServerLaunchPlan.Create("codex.exe", @"C:\isolated"));
    }

    private static HostWindowSnapshot Window(string build) =>
        new(new IntPtr(42), new RectD(0, 0, 1400, 900), true, 1, build);

    private static AllowanceSnapshot Snapshot() => new(
        24, 76, DateTimeOffset.FromUnixTimeSeconds(1_785_628_824), DateTimeOffset.UnixEpoch);

    private sealed class StubLocator(HostWindowSnapshot? value) : IHostWindowLocator
    {
        public ValueTask<HostWindowSnapshot?> FindAsync(CancellationToken cancellationToken) => ValueTask.FromResult(value);
    }

    private sealed class SequencedLocator(params HostWindowSnapshot[] values) : IHostWindowLocator
    {
        private int index;
        public ValueTask<HostWindowSnapshot?> FindAsync(CancellationToken cancellationToken) =>
            ValueTask.FromResult<HostWindowSnapshot?>(values[Math.Min(index++, values.Length - 1)]);
    }

    private sealed class StubScanner(TitlebarSnapshot? value = null) : ITitlebarScanner
    {
        public int InvalidateCount { get; private set; }
        public ValueTask<TitlebarSnapshot> ScanAsync(HostWindowSnapshot host, CancellationToken cancellationToken) =>
            ValueTask.FromResult(value ?? new TitlebarSnapshot(host.Bounds.Right, Array.Empty<RectD>()));
        public void Invalidate() => InvalidateCount++;
    }

    private sealed class RejectingScanner : ITitlebarScanner
    {
        public ValueTask<TitlebarSnapshot> ScanAsync(HostWindowSnapshot host, CancellationToken cancellationToken) =>
            ValueTask.FromException<TitlebarSnapshot>(new WindowsDeviceValidationRequiredException(host.BuildIdentity));
        public void Invalidate() { }
    }

    private sealed class RecordingOverlay : IOverlaySurface
    {
        public int HideCount { get; private set; }
        public OverlayPresentation? LastPresentation { get; private set; }
        public ValueTask HideAsync(CancellationToken cancellationToken) { HideCount++; LastPresentation = null; return ValueTask.CompletedTask; }
        public ValueTask ShowAsync(OverlayPresentation presentation, CancellationToken cancellationToken) { LastPresentation = presentation; return ValueTask.CompletedTask; }
    }
}
