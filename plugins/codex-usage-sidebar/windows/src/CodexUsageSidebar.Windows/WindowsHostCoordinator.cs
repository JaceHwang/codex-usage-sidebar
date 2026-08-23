using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Windows;

public sealed class WindowsHostCoordinator
{
    private const double MiddleIndicatorGap = 0.5;
    private const double RightIndicatorGap = 0;
    private readonly IHostWindowLocator locator;
    private readonly ITitlebarScanner scanner;
    private readonly IOverlaySurface overlay;
    private readonly Func<DateTimeOffset> now;
    private readonly IRuntimeStateStore? runtimeStateStore;
    private string? lastBuildIdentity;
    private DisplayLanguage? lastLanguage;

    public WindowsHostCoordinator(
        IHostWindowLocator locator,
        ITitlebarScanner scanner,
        IOverlaySurface overlay,
        Func<DateTimeOffset>? now = null,
        IRuntimeStateStore? runtimeStateStore = null)
    {
        this.locator = locator;
        this.scanner = scanner;
        this.overlay = overlay;
        this.now = now ?? (() => DateTimeOffset.Now);
        this.runtimeStateStore = runtimeStateStore;
    }

    public CompatibilityDecision? LastCompatibilityDecision { get; private set; }

    public ValueTask<HostRuntimeState> ReconcileAsync(
        AllowanceSnapshot? snapshot,
        CancellationToken cancellationToken) =>
        ReconcileAsync(snapshot, DisplayLanguage.SimplifiedChinese, cancellationToken);

    public async ValueTask<HostRuntimeState> ReconcileAsync(
        AllowanceSnapshot? snapshot,
        DisplayLanguage language,
        CancellationToken cancellationToken,
        TokenUsageSnapshot? tokenUsage = null,
        AccountIdentity? account = null)
    {
        var host = await locator.FindAsync(cancellationToken).ConfigureAwait(false);
        if (host is null)
        {
            lastBuildIdentity = null;
            lastLanguage = null;
            await overlay.HideAsync(cancellationToken).ConfigureAwait(false);
            return await CompleteAsync(
                HostRuntimeState.WaitingForCodex,
                new CompatibilityDecision(
                    SemanticCompatibility.Unknown,
                    ProfileCompatibility.Invalid,
                    SafeDockPlacement.None,
                    CompatibilityFailureCode.MissingCodexWindow),
                cancellationToken).ConfigureAwait(false);
        }

        if (lastBuildIdentity is not null
            && !string.Equals(lastBuildIdentity, host.BuildIdentity, StringComparison.Ordinal))
        {
            scanner.Invalidate();
        }
        lastBuildIdentity = host.BuildIdentity;
        if (lastLanguage is not null && lastLanguage != language)
        {
            scanner.Invalidate();
        }
        lastLanguage = language;

        // Foreground detection can transiently return no window while Codex is
        // still visible (for example across shell/tool transitions). The WPF
        // surface is owned by the validated Codex HWND, so Windows keeps it in
        // the owner's z-order without a brittle foreground visibility gate.
        if (snapshot is null)
        {
            await overlay.HideAsync(cancellationToken).ConfigureAwait(false);
            return await CompleteAsync(
                HostRuntimeState.Hidden,
                new CompatibilityDecision(
                    SemanticCompatibility.Unknown,
                    ProfileCompatibility.Unknown,
                    SafeDockPlacement.None,
                    CompatibilityFailureCode.MissingQuotaSnapshot),
                cancellationToken).ConfigureAwait(false);
        }

        var freshness = RefreshPolicy.Freshness(snapshot.ReceivedAt, now());
        if (freshness == SnapshotFreshness.Hidden)
        {
            await overlay.HideAsync(cancellationToken).ConfigureAwait(false);
            return await CompleteAsync(
                HostRuntimeState.Hidden,
                new CompatibilityDecision(
                    SemanticCompatibility.Valid,
                    ProfileCompatibility.Validated,
                    SafeDockPlacement.None,
                    CompatibilityFailureCode.None),
                cancellationToken).ConfigureAwait(false);
        }

        var titlebar = scanner.TryGetCurrent(host);
        if (titlebar is null)
        {
            try
            {
                titlebar = await scanner.ScanAsync(host, cancellationToken).ConfigureAwait(false);
            }
            catch (InvalidSelectorCatalogException)
            {
                return await FailUnresolvedTitlebarAsync(
                    CompatibilityFailureCode.InvalidCatalog, cancellationToken).ConfigureAwait(false);
            }
            catch (WindowsDeviceValidationRequiredException)
            {
                titlebar = scanner.TryGetRetained(host);
                if (titlebar is null)
                {
                    return await FailUnresolvedTitlebarAsync(
                        CompatibilityFailureCode.UiaUnavailable, cancellationToken).ConfigureAwait(false);
                }
            }
            catch (OperationCanceledException)
            {
                throw;
            }
            catch (Exception)
            {
                titlebar = scanner.TryGetRetained(host);
                if (titlebar is null)
                {
                    return await FailUnresolvedTitlebarAsync(
                        CompatibilityFailureCode.UiaUnavailable, cancellationToken).ConfigureAwait(false);
                }
            }
        }
        var scale = host.DpiScale;
        var indicatorHeight = titlebar.OpenLocationBounds.Height / scale;
        var indicatorWidth = OverlayVisualMetrics.IndicatorWidthForHeight(indicatorHeight) * scale;
        var placement = PlacementResolver.ResolveResponsive(
            titlebar.ToolbarBounds,
            titlebar.OpenLocationBounds,
            titlebar.TitleBounds,
            indicatorWidth,
            MiddleIndicatorGap * scale,
            titlebar.Obstacles,
            titlebar.RightToolbarBounds,
            titlebar.RightObstacles,
            RightIndicatorGap * scale);
        if (placement is null)
        {
            await overlay.HideAsync(cancellationToken).ConfigureAwait(false);
            return await CompleteAsync(
                HostRuntimeState.Hidden,
                new CompatibilityDecision(
                    SemanticCompatibility.Valid,
                    ProfileCompatibility.Validated,
                    SafeDockPlacement.None,
                    CompatibilityFailureCode.NoCollisionFreeSlot),
                cancellationToken).ConfigureAwait(false);
        }

        await overlay.ShowAsync(
            new OverlayPresentation(
                host.Handle,
                host.DpiScale,
                language,
                snapshot,
                placement.Value,
                    freshness,
                    new PointD(
                        titlebar.ToolbarBounds.X + (4 * scale),
                    titlebar.ToolbarBounds.Y + (4 * scale)),
                tokenUsage,
                account),
            cancellationToken).ConfigureAwait(false);
        return await CompleteAsync(
            HostRuntimeState.Visible,
            new CompatibilityDecision(
                SemanticCompatibility.Valid,
                ProfileCompatibility.Validated,
                SafeDockPlacement.Titlebar,
                CompatibilityFailureCode.None),
            cancellationToken).ConfigureAwait(false);
    }

    private async ValueTask<HostRuntimeState> FailUnresolvedTitlebarAsync(
        CompatibilityFailureCode failureCode,
        CancellationToken cancellationToken)
    {
        await overlay.HideAsync(cancellationToken).ConfigureAwait(false);
        return await CompleteAsync(
            HostRuntimeState.DeviceValidationRequired,
            new CompatibilityDecision(
                SemanticCompatibility.Invalid,
                ProfileCompatibility.Invalid,
                SafeDockPlacement.None,
                failureCode),
            cancellationToken).ConfigureAwait(false);
    }

    private async ValueTask<HostRuntimeState> CompleteAsync(
        HostRuntimeState state,
        CompatibilityDecision decision,
        CancellationToken cancellationToken)
    {
        LastCompatibilityDecision = decision;
        if (runtimeStateStore is not null)
        {
            try
            {
                await runtimeStateStore.WriteAsync(
                    new RuntimeStateOutcome(state, decision, now()),
                    cancellationToken).ConfigureAwait(false);
            }
            catch (OperationCanceledException)
            {
                throw;
            }
            catch (Exception)
            {
                // Persisted telemetry must not change overlay behavior.
            }
        }

        return state;
    }
}
