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
        Assert.AreEqual(1068, overlay.LastPresentation?.Placement.Frame.X);
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
    public async Task HidesOverlayWhenNoCollisionFreeTitlebarSlotExists()
    {
        var overlay = new RecordingOverlay();
        var scanner = new StubScanner(new TitlebarSnapshot(300, [new RectD(0, 0, 300, 48)]));
        var coordinator = new WindowsHostCoordinator(
            new StubLocator(new HostWindowSnapshot(
                new IntPtr(42), new RectD(0, 0, 400, 800), true, 1, "codex-build-a")),
            scanner,
            overlay);

        var result = await coordinator.ReconcileAsync(Snapshot(), CancellationToken.None);

        Assert.AreEqual(HostRuntimeState.Hidden, result);
        Assert.AreEqual(1, overlay.HideCount);
        Assert.IsNull(overlay.LastPresentation);
    }

    [TestMethod]
    public async Task ScannerFailureHidesOverlayInsteadOfEscapingTheUiLoop()
    {
        var overlay = new RecordingOverlay();
        var coordinator = new WindowsHostCoordinator(
            new StubLocator(Window("codex-build-a")),
            new FailingScanner(),
            overlay);

        var result = await coordinator.ReconcileAsync(Snapshot(), CancellationToken.None);

        Assert.AreEqual(HostRuntimeState.DeviceValidationRequired, result);
        Assert.AreEqual(1, overlay.HideCount);
    }

    [TestMethod]
    public async Task ScalesIndicatorGeometryInThePhysicalPixelCoordinateSpace()
    {
        var window = new HostWindowSnapshot(
            new IntPtr(42), new RectD(-3000, 0, 4096, 2200), true, 2, "codex-build-a");
        var scanner = new StubScanner(new TitlebarSnapshot(500, []));
        var overlay = new RecordingOverlay();
        var coordinator = new WindowsHostCoordinator(new StubLocator(window), scanner, overlay);

        var result = await coordinator.ReconcileAsync(Snapshot(), CancellationToken.None);

        Assert.AreEqual(HostRuntimeState.Visible, result);
        Assert.AreEqual(416, overlay.LastPresentation?.Placement.Frame.Width);
        Assert.AreEqual(80, overlay.LastPresentation?.Placement.Frame.Height);
        Assert.AreEqual(8, overlay.LastPresentation?.Placement.Frame.Y);
    }

    [TestMethod]
    public async Task HidesSnapshotsAtTheFreshnessDeadlineBeforeScanningUia()
    {
        var scanner = new StubScanner();
        var overlay = new RecordingOverlay();
        var now = DateTimeOffset.UnixEpoch.AddSeconds(300);
        var coordinator = new WindowsHostCoordinator(
            new StubLocator(Window("codex-build-a")), scanner, overlay, () => now);
        var stale = Snapshot() with { ReceivedAt = DateTimeOffset.UnixEpoch };

        var result = await coordinator.ReconcileAsync(stale, CancellationToken.None);

        Assert.AreEqual(HostRuntimeState.Hidden, result);
        Assert.AreEqual(0, scanner.ScanCount);
        Assert.AreEqual(1, overlay.HideCount);
    }

    [TestMethod]
    public async Task MarksSnapshotsDimmedAfterTwoMinutes()
    {
        var now = DateTimeOffset.UnixEpoch.AddSeconds(120);
        var overlay = new RecordingOverlay();
        var coordinator = new WindowsHostCoordinator(
            new StubLocator(Window("codex-build-a")), new StubScanner(), overlay, () => now);
        var snapshot = Snapshot() with { ReceivedAt = DateTimeOffset.UnixEpoch };

        await coordinator.ReconcileAsync(snapshot, CancellationToken.None);

        Assert.AreEqual(SnapshotFreshness.Dimmed, overlay.LastPresentation?.Freshness);
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

    [TestMethod]
    public void HostArgumentsAcceptTheExactHookContract()
    {
        var result = WindowsHostArguments.TryParse([
            "--background",
            "--plugin-root", @"C:\fixture\plugin",
            "--plugin-data", @"C:\fixture\data",
        ]);

        Assert.IsNotNull(result);
        Assert.IsTrue(result.Background);
        Assert.AreEqual(@"C:\fixture\plugin", result.PluginRoot);
        Assert.AreEqual(@"C:\fixture\data", result.PluginData);
    }

    [TestMethod]
    public void HostArgumentsRejectUnknownDuplicateAndIncompleteOptions()
    {
        Assert.IsNull(WindowsHostArguments.TryParse(["--unknown"]));
        Assert.IsNull(WindowsHostArguments.TryParse(["--plugin-root"]));
        Assert.IsNull(WindowsHostArguments.TryParse([
            "--plugin-data", @"C:\one", "--plugin-data", @"C:\two",
        ]));
    }

    [TestMethod]
    public void HostSingletonRefusesASecondLeaseUntilTheFirstIsDisposed()
    {
        var identity = $"test-{Guid.NewGuid():N}";
        using var first = PerUserHostSingleton.TryAcquire(identity);

        Assert.IsNotNull(first);
        Assert.IsNull(PerUserHostSingleton.TryAcquire(identity));

        first.Dispose();
        using var afterRelease = PerUserHostSingleton.TryAcquire(identity);
        Assert.IsNotNull(afterRelease);
    }

    [TestMethod]
    public void ValidatedTitlebarCacheIsKeyedByHandleBuildDpiAndPhysicalGeometry()
    {
        long timestamp = 10_000;
        var cache = new ValidatedTitlebarCache(
            () => timestamp,
            timestampFrequency: 1_000,
            TimeSpan.FromSeconds(1));
        var host = new HostWindowSnapshot(
            new IntPtr(9), new RectD(-2000, 0, 1600, 1200), true, 1.5, "build-a");
        var snapshot = new TitlebarSnapshot(-500, []);
        cache.Store(host, snapshot);

        Assert.AreSame(snapshot, cache.TryGet(host));
        Assert.IsNull(cache.TryGet(host with { Bounds = host.Bounds with { X = -1999 } }));
        Assert.IsNull(cache.TryGet(host with { DpiScale = 2 }));
        Assert.IsNull(cache.TryGet(host with { BuildIdentity = "build-b" }));

        timestamp += 1_000;
        Assert.IsNull(cache.TryGet(host));

        cache.Invalidate();
        Assert.IsNull(cache.TryGet(host));
    }

    [TestMethod]
    public async Task HidesBeforeRevalidatingAnExpiredUiaStructure()
    {
        var overlay = new RecordingOverlay();
        var scanner = new StubScanner { ValidationCurrent = false };
        var coordinator = new WindowsHostCoordinator(
            new StubLocator(Window("codex-build-a")), scanner, overlay);

        await coordinator.ReconcileAsync(Snapshot(), CancellationToken.None);

        CollectionAssert.AreEqual(new[] { "hide", "show" }, overlay.Events.ToArray());
    }

    private static HostWindowSnapshot Window(string build) =>
        new(new IntPtr(42), new RectD(0, 0, 1400, 900), true, 1, build);

    private static AllowanceSnapshot Snapshot() => new(
        24, 76, DateTimeOffset.FromUnixTimeSeconds(1_785_628_824), DateTimeOffset.Now);

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
        public bool ValidationCurrent { get; set; } = true;
        public int InvalidateCount { get; private set; }
        public int ScanCount { get; private set; }
        public ValueTask<TitlebarSnapshot> ScanAsync(HostWindowSnapshot host, CancellationToken cancellationToken)
        {
            ScanCount++;
            return ValueTask.FromResult(value ?? new TitlebarSnapshot(host.Bounds.Right, Array.Empty<RectD>()));
        }
        public TitlebarSnapshot? TryGetCurrent(HostWindowSnapshot host) => ValidationCurrent
            ? value ?? new TitlebarSnapshot(host.Bounds.Right, Array.Empty<RectD>())
            : null;
        public void Invalidate() => InvalidateCount++;
    }

    private sealed class RejectingScanner : ITitlebarScanner
    {
        public ValueTask<TitlebarSnapshot> ScanAsync(HostWindowSnapshot host, CancellationToken cancellationToken) =>
            ValueTask.FromException<TitlebarSnapshot>(new WindowsDeviceValidationRequiredException(host.BuildIdentity));
        public void Invalidate() { }
    }

    private sealed class FailingScanner : ITitlebarScanner
    {
        public ValueTask<TitlebarSnapshot> ScanAsync(HostWindowSnapshot host, CancellationToken cancellationToken) =>
            ValueTask.FromException<TitlebarSnapshot>(new InvalidOperationException("UIA unavailable"));
        public void Invalidate() { }
    }

    private sealed class RecordingOverlay : IOverlaySurface
    {
        public List<string> Events { get; } = new();
        public int HideCount { get; private set; }
        public OverlayPresentation? LastPresentation { get; private set; }
        public ValueTask HideAsync(CancellationToken cancellationToken) { Events.Add("hide"); HideCount++; LastPresentation = null; return ValueTask.CompletedTask; }
        public ValueTask ShowAsync(OverlayPresentation presentation, CancellationToken cancellationToken) { Events.Add("show"); LastPresentation = presentation; return ValueTask.CompletedTask; }
    }
}
