using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Windows;

public sealed class WindowsHostCoordinator
{
    private const string FallbackBuildIdentity = "151.0.7922.76";
    private const double IndicatorGap = 8;
    private readonly IHostWindowLocator locator;
    private readonly ITitlebarScanner scanner;
    private readonly IOverlaySurface overlay;
    private readonly Func<DateTimeOffset> now;
    private string? lastBuildIdentity;
    private DisplayLanguage? lastLanguage;

    public WindowsHostCoordinator(
        IHostWindowLocator locator,
        ITitlebarScanner scanner,
        IOverlaySurface overlay,
        Func<DateTimeOffset>? now = null)
    {
        this.locator = locator;
        this.scanner = scanner;
        this.overlay = overlay;
        this.now = now ?? (() => DateTimeOffset.Now);
    }

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
            return HostRuntimeState.WaitingForCodex;
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
            return HostRuntimeState.Hidden;
        }

        var freshness = RefreshPolicy.Freshness(snapshot.ReceivedAt, now());
        if (freshness == SnapshotFreshness.Hidden)
        {
            await overlay.HideAsync(cancellationToken).ConfigureAwait(false);
            return HostRuntimeState.Hidden;
        }

        var titlebar = scanner.TryGetCurrent(host);
        if (titlebar is null)
        {
            try
            {
                titlebar = await scanner.ScanAsync(host, cancellationToken).ConfigureAwait(false);
            }
            catch (WindowsDeviceValidationRequiredException)
            {
                titlebar = scanner.TryGetRetained(host);
                if (titlebar is null)
                {
                    return await ShowKnownBuildFallbackAsync(
                        host, snapshot, language, freshness, tokenUsage, account, cancellationToken).ConfigureAwait(false);
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
                    return await ShowKnownBuildFallbackAsync(
                        host, snapshot, language, freshness, tokenUsage, account, cancellationToken).ConfigureAwait(false);
                }
            }
        }
        var scale = host.DpiScale;
        var placement = PlacementResolver.ResolveResponsive(
            titlebar.ToolbarBounds,
            titlebar.OpenLocationBounds,
            titlebar.TitleBounds,
            OverlayVisualMetrics.IndicatorWidth * scale,
            IndicatorGap * scale,
            titlebar.Obstacles,
            titlebar.RightToolbarBounds,
            titlebar.RightObstacles);
        if (placement is null)
        {
            await overlay.HideAsync(cancellationToken).ConfigureAwait(false);
            return HostRuntimeState.Hidden;
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
        return HostRuntimeState.Visible;
    }

    private async ValueTask<HostRuntimeState> ShowKnownBuildFallbackAsync(
        HostWindowSnapshot host,
        AllowanceSnapshot snapshot,
        DisplayLanguage language,
        SnapshotFreshness freshness,
        TokenUsageSnapshot? tokenUsage,
        AccountIdentity? account,
        CancellationToken cancellationToken)
    {
        var scale = host.DpiScale;
        var width = OverlayVisualMetrics.IndicatorWidth * scale;
        var height = 28 * scale;
        if (!string.Equals(host.BuildIdentity, FallbackBuildIdentity, StringComparison.Ordinal)
            || !double.IsFinite(scale)
            || scale <= 0
            || !double.IsFinite(host.Bounds.X)
            || !double.IsFinite(host.Bounds.Y)
            || !double.IsFinite(host.Bounds.Width)
            || !double.IsFinite(host.Bounds.Height)
            || host.Bounds.Width < width + (32 * scale)
            || host.Bounds.Height < 300 * scale)
        {
            await overlay.HideAsync(cancellationToken).ConfigureAwait(false);
            return HostRuntimeState.DeviceValidationRequired;
        }

        var placement = new PlacementResult(
            PlacementSurface.Content,
            new RectD(
                host.Bounds.X + ((host.Bounds.Width - width) / 2),
                host.Bounds.Y + (50.5 * scale),
                width,
                height));
        await overlay.ShowAsync(
            new OverlayPresentation(
                host.Handle,
                scale,
                language,
                snapshot,
                placement,
                freshness,
                new PointD(host.Bounds.X + (4 * scale), host.Bounds.Y + (42 * scale)),
                tokenUsage,
                account),
            cancellationToken).ConfigureAwait(false);
        return HostRuntimeState.Visible;
    }
}
