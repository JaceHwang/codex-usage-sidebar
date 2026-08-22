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
        },
        new RectD(400, 80, 1600, 92),
        new RectD(1500, 98, 180, 56),
        new RectD(420, 98, 300, 56)));
        var overlay = new RecordingOverlay();
        var coordinator = new WindowsHostCoordinator(new StubLocator(window), scanner, overlay);

        var result = await coordinator.ReconcileAsync(Snapshot(), CancellationToken.None);

        Assert.AreEqual(HostRuntimeState.Visible, result);
        Assert.AreEqual(PlacementSurface.Content, overlay.LastPresentation?.Placement.Surface);
        Assert.AreEqual(1156, overlay.LastPresentation?.Placement.Frame.X);
        Assert.AreEqual(98, overlay.LastPresentation?.Placement.Frame.Y);
        Assert.AreEqual(328, overlay.LastPresentation?.Placement.Frame.Width);
        Assert.AreEqual(56, overlay.LastPresentation?.Placement.Frame.Height);
        Assert.AreEqual(76, overlay.LastPresentation?.Snapshot.RemainingPercent);
    }

    [TestMethod]
    public async Task CarriesTokenUsageAndAccountIdentityIntoTheOverlayPresentation()
    {
        var window = new HostWindowSnapshot(
            new IntPtr(42), new RectD(0, 0, 2048, 1100), true, 2, "codex-build-a");
        var scanner = new StubScanner(new TitlebarSnapshot(
            1500,
            Array.Empty<RectD>(),
            new RectD(400, 80, 1600, 92),
            new RectD(1500, 98, 180, 56),
            new RectD(420, 98, 300, 56)));
        var overlay = new RecordingOverlay();
        var coordinator = new WindowsHostCoordinator(new StubLocator(window), scanner, overlay);
        var usage = new TokenUsageSnapshot(
            DateTimeOffset.UnixEpoch,
            Array.Empty<TokenUsageDay>(),
            null,
            TokenUsageAvailability.Unsupported);
        var account = new AccountIdentity("Jace", "jace@example.com", null);

        await coordinator.ReconcileAsync(
            Snapshot(),
            DisplayLanguage.English,
            CancellationToken.None,
            usage,
            account);

        Assert.AreSame(usage, overlay.LastPresentation?.TokenUsage);
        Assert.AreSame(account, overlay.LastPresentation?.Account);
        Assert.AreEqual("0.3.1", overlay.LastPresentation?.Version);
    }

    [TestMethod]
    public async Task KeepsOverlayAttachedWhenForegroundDetectionTemporarilyReturnsFalse()
    {
        var window = Window("codex-build-a") with { IsForeground = false };
        var overlay = new RecordingOverlay();
        var coordinator = new WindowsHostCoordinator(
            new StubLocator(window), new StubScanner(), overlay);

        var result = await coordinator.ReconcileAsync(Snapshot(), CancellationToken.None);

        Assert.AreEqual(HostRuntimeState.Visible, result);
        Assert.IsNotNull(overlay.LastPresentation);
        Assert.AreEqual(window.Handle, overlay.LastPresentation.OwnerHandle);
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
    public async Task LanguageChangeInvalidatesCachedTitlebarAndRepositionsTheIndicator()
    {
        var window = new HostWindowSnapshot(
            new IntPtr(42), new RectD(-13, -13, 3026, 1930), true, 2, "151.0.7922.76");
        var scanner = new LanguageSensitiveScanner(
            new TitlebarSnapshot(
                2620,
                [new RectD(2620, 88, 182, 56)],
                new RectD(478, 70, 2522, 92),
                new RectD(2620, 88, 182, 56),
                new RectD(494, 88, 542, 56)),
            new TitlebarSnapshot(
                2021,
                [new RectD(2021, 88, 183, 56)],
                new RectD(478, 70, 2522, 92),
                new RectD(2021, 88, 183, 56),
                new RectD(494, 88, 542, 56)));
        var overlay = new RecordingOverlay();
        var coordinator = new WindowsHostCoordinator(new StubLocator(window), scanner, overlay);

        await coordinator.ReconcileAsync(Snapshot(), DisplayLanguage.SimplifiedChinese, CancellationToken.None);
        var simplifiedFrame = overlay.LastPresentation!.Placement.Frame;
        await coordinator.ReconcileAsync(Snapshot(), DisplayLanguage.English, CancellationToken.None);

        Assert.AreEqual(1, scanner.InvalidateCount);
        Assert.AreEqual(DisplayLanguage.English, overlay.LastPresentation?.Language);
        Assert.AreNotEqual(simplifiedFrame, overlay.LastPresentation?.Placement.Frame);
        Assert.AreEqual(new RectD(1677, 88, 328, 56), overlay.LastPresentation?.Placement.Frame);
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
    public async Task KnownBuildUsesAWindowRelativeFallbackWhenUiaIsUnavailable()
    {
        var window = new HostWindowSnapshot(
            new IntPtr(42), new RectD(-13, -13, 3026, 1930), true, 2, "151.0.7922.76");
        var overlay = new RecordingOverlay();
        var coordinator = new WindowsHostCoordinator(
            new StubLocator(window),
            new RejectingScanner(),
            overlay);

        var result = await coordinator.ReconcileAsync(Snapshot(), CancellationToken.None);

        Assert.AreEqual(HostRuntimeState.Visible, result);
        Assert.AreEqual(PlacementSurface.Content, overlay.LastPresentation?.Placement.Surface);
        Assert.AreEqual(new RectD(1336, 88, 328, 56), overlay.LastPresentation?.Placement.Frame);
        Assert.AreEqual(window.Handle, overlay.LastPresentation?.OwnerHandle);
    }

    [TestMethod]
    public async Task UnknownBuildStillHidesWhenUiaIsUnavailable()
    {
        var overlay = new RecordingOverlay();
        var coordinator = new WindowsHostCoordinator(
            new StubLocator(Window("151.0.7922.77")),
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
        var scanner = new StubScanner(new TitlebarSnapshot(
            300,
            [new RectD(300, 60, 80, 28)],
            new RectD(0, 60, 400, 46),
            new RectD(300, 69, 80, 28),
            new RectD(8, 69, 280, 28)));
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
    public async Task UsesValidatedRightToolbarWhenTheMeasuredLocalGapIsTooNarrow()
    {
        var window = new HostWindowSnapshot(
            new IntPtr(42), new RectD(-13, -13, 3026, 1930), true, 2, "codex-build-a");
        var scanner = new StubScanner(new TitlebarSnapshot(
            1069,
            [new RectD(1069, 88, 183, 56), new RectD(1251, 88, 47, 56)],
            new RectD(478, 70, 2522, 92),
            new RectD(1069, 88, 183, 56),
            new RectD(494, 88, 533, 56),
            new RectD(1395, 70, 1461, 92),
            [new RectD(2856, 88, 56, 56)]));
        var overlay = new RecordingOverlay();
        var coordinator = new WindowsHostCoordinator(new StubLocator(window), scanner, overlay);

        var result = await coordinator.ReconcileAsync(Snapshot(), CancellationToken.None);

        Assert.AreEqual(HostRuntimeState.Visible, result);
        Assert.AreEqual(PlacementSurface.RightToolbar, overlay.LastPresentation?.Placement.Surface);
        Assert.AreEqual(new RectD(2512, 88, 328, 56), overlay.LastPresentation?.Placement.Frame);
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
        var scanner = new StubScanner(new TitlebarSnapshot(
            500,
            [],
            new RectD(-2600, 70, 3600, 92),
            new RectD(500, 88, 183, 56),
            new RectD(-2500, 88, 500, 56)));
        var overlay = new RecordingOverlay();
        var coordinator = new WindowsHostCoordinator(new StubLocator(window), scanner, overlay);

        var result = await coordinator.ReconcileAsync(Snapshot(), CancellationToken.None);

        Assert.AreEqual(HostRuntimeState.Visible, result);
        Assert.AreEqual(328, overlay.LastPresentation?.Placement.Frame.Width);
        Assert.AreEqual(56, overlay.LastPresentation?.Placement.Frame.Height);
        Assert.AreEqual(88, overlay.LastPresentation?.Placement.Frame.Y);
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
    public void OverlayVisualMetricsMatchTheMacOsV023Baseline()
    {
        Assert.AreEqual(164, OverlayVisualMetrics.IndicatorWidth);
        Assert.AreEqual(360, OverlayVisualMetrics.DetailWidth);
        Assert.AreEqual(18, OverlayVisualMetrics.HeaderTitleFontSize);
        Assert.AreEqual(9, OverlayVisualMetrics.VersionBadgeFontSize);
        Assert.AreEqual(18, OverlayVisualMetrics.VersionBadgeHeight);
        Assert.AreEqual(28, OverlayVisualMetrics.RemainingPercentFontSize);
        Assert.AreEqual(13, OverlayVisualMetrics.DetailValueFontSize);
        Assert.AreEqual(16, OverlayVisualMetrics.CountdownDigitFontSize);
        Assert.AreEqual(11, OverlayVisualMetrics.CountdownUnitFontSize);
        Assert.AreEqual(4, OverlayVisualMetrics.ProgressTrackHeight);
    }

    [TestMethod]
    public void PassiveOverlayReassertsNativeVisibilityWithoutActivation()
    {
        Assert.AreEqual(0x0250u, OverlayWindowPolicy.PositionFlags);
    }

    [TestMethod]
    public void PassiveOverlayPointerHitTestingUsesPhysicalWindowRectangles()
    {
        var indicator = new RectD(2512, 88, 328, 56);
        var detail = new RectD(2240, 156, 600, 400);

        Assert.IsTrue(OverlayPointerPolicy.IsInside(new PointD(2676, 116), indicator));
        Assert.IsTrue(OverlayPointerPolicy.IsInside(new PointD(2300, 200), detail));
        Assert.IsFalse(OverlayPointerPolicy.IsInside(new PointD(2511, 116), indicator));
        Assert.IsFalse(OverlayPointerPolicy.IsInside(new PointD(2840, 116), indicator));
        Assert.IsFalse(OverlayPointerPolicy.IsInside(new PointD(double.NaN, 116), indicator));
    }

    [TestMethod]
    public void OverlayThemeFollowsTheValidatedTitlebarPixelAndHighContrastOverride()
    {
        Assert.AreEqual(OverlayThemeKind.Dark, OverlayThemePolicy.Resolve(6, 4, 1, highContrast: false));
        Assert.AreEqual(OverlayThemeKind.Light, OverlayThemePolicy.Resolve(248, 248, 248, highContrast: false));
        Assert.AreEqual(OverlayThemeKind.HighContrast, OverlayThemePolicy.Resolve(248, 248, 248, highContrast: true));
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
    public void ValidatedTitlebarCacheHasA100MillisecondFreshWindowAnd750MillisecondRetentionWindow()
    {
        long timestamp = 10_000;
        var cache = new ValidatedTitlebarCache(
            () => timestamp,
            timestampFrequency: 1_000,
            TimeSpan.FromMilliseconds(100),
            TimeSpan.FromMilliseconds(750));
        var host = new HostWindowSnapshot(
            new IntPtr(9), new RectD(-2000, 0, 1600, 1200), true, 1.5, "build-a");
        var snapshot = new TitlebarSnapshot(-500, []);
        cache.Store(host, snapshot);

        Assert.AreSame(snapshot, cache.TryGet(host));
        Assert.IsNull(cache.TryGet(host with { Bounds = host.Bounds with { X = -1999 } }));
        Assert.IsNull(cache.TryGet(host with { DpiScale = 2 }));
        Assert.IsNull(cache.TryGet(host with { BuildIdentity = "build-b" }));

        timestamp += 100;
        Assert.IsNull(cache.TryGet(host));
        Assert.AreSame(snapshot, cache.TryGetRetained(host));

        timestamp += 650;
        Assert.IsNull(cache.TryGetRetained(host));

        cache.Invalidate();
        Assert.IsNull(cache.TryGet(host));
    }

    [TestMethod]
    public async Task RevalidatesAnExpiredUiaStructureWithoutHidingAVisibleOverlayFirst()
    {
        var overlay = new RecordingOverlay();
        var scanner = new StubScanner { ValidationCurrent = false };
        var coordinator = new WindowsHostCoordinator(
            new StubLocator(Window("codex-build-a")), scanner, overlay);

        await coordinator.ReconcileAsync(Snapshot(), CancellationToken.None);

        CollectionAssert.AreEqual(new[] { "show" }, overlay.Events.ToArray());
    }

    [TestMethod]
    public async Task RetainsTheLastSafePlacementDuringATransientUiaFailure()
    {
        var window = Window("codex-build-a");
        var retained = new TitlebarSnapshot(
            1000,
            [],
            new RectD(200, 60, 1100, 46),
            new RectD(1000, 69, 180, 28),
            new RectD(220, 69, 300, 28));
        var overlay = new RecordingOverlay();
        var coordinator = new WindowsHostCoordinator(
            new StubLocator(window),
            new RetainingFailingScanner(retained),
            overlay);

        var result = await coordinator.ReconcileAsync(Snapshot(), CancellationToken.None);

        Assert.AreEqual(HostRuntimeState.Visible, result);
        CollectionAssert.AreEqual(new[] { "show" }, overlay.Events.ToArray());
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
            return ValueTask.FromResult(value ?? SnapshotFor(host));
        }
        public TitlebarSnapshot? TryGetCurrent(HostWindowSnapshot host) => ValidationCurrent
            ? value ?? SnapshotFor(host)
            : null;
        public void Invalidate() => InvalidateCount++;

        private static TitlebarSnapshot SnapshotFor(HostWindowSnapshot host) => new(
            host.Bounds.Right - 100,
            Array.Empty<RectD>(),
            new RectD(host.Bounds.X, host.Bounds.Y + 60, host.Bounds.Width, 46 * host.DpiScale),
            new RectD(
                host.Bounds.Right - 100,
                host.Bounds.Y + 69,
                80,
                28 * host.DpiScale),
            new RectD(
                host.Bounds.X + 8,
                host.Bounds.Y + 69,
                200,
                28 * host.DpiScale));
    }

    private sealed class LanguageSensitiveScanner(params TitlebarSnapshot[] snapshots) : ITitlebarScanner
    {
        private int index;
        private TitlebarSnapshot? cached;
        public int InvalidateCount { get; private set; }

        public TitlebarSnapshot? TryGetCurrent(HostWindowSnapshot host) => cached;

        public ValueTask<TitlebarSnapshot> ScanAsync(HostWindowSnapshot host, CancellationToken cancellationToken)
        {
            cached = snapshots[Math.Min(index++, snapshots.Length - 1)];
            return ValueTask.FromResult(cached);
        }

        public void Invalidate()
        {
            InvalidateCount++;
            cached = null;
        }
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

    private sealed class RetainingFailingScanner(TitlebarSnapshot retained) : ITitlebarScanner
    {
        public TitlebarSnapshot? TryGetRetained(HostWindowSnapshot host) => retained;
        public ValueTask<TitlebarSnapshot> ScanAsync(HostWindowSnapshot host, CancellationToken cancellationToken) =>
            ValueTask.FromException<TitlebarSnapshot>(new WindowsDeviceValidationRequiredException(host.BuildIdentity));
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
