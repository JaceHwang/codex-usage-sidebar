using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Windows;

public sealed class WindowsHostCoordinator
{
    private const double IndicatorWidth = 208;
    private const double IndicatorGap = 8;
    private readonly IHostWindowLocator locator;
    private readonly ITitlebarScanner scanner;
    private readonly IOverlaySurface overlay;
    private readonly Func<DateTimeOffset> now;
    private string? lastBuildIdentity;

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

    public async ValueTask<HostRuntimeState> ReconcileAsync(
        AllowanceSnapshot? snapshot,
        CancellationToken cancellationToken)
    {
        var host = await locator.FindAsync(cancellationToken).ConfigureAwait(false);
        if (host is null)
        {
            lastBuildIdentity = null;
            await overlay.HideAsync(cancellationToken).ConfigureAwait(false);
            return HostRuntimeState.WaitingForCodex;
        }

        if (lastBuildIdentity is not null
            && !string.Equals(lastBuildIdentity, host.BuildIdentity, StringComparison.Ordinal))
        {
            scanner.Invalidate();
        }
        lastBuildIdentity = host.BuildIdentity;

        if (!host.IsForeground || snapshot is null)
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
            await overlay.HideAsync(cancellationToken).ConfigureAwait(false);
            try
            {
                titlebar = await scanner.ScanAsync(host, cancellationToken).ConfigureAwait(false);
            }
            catch (WindowsDeviceValidationRequiredException)
            {
                return HostRuntimeState.DeviceValidationRequired;
            }
            catch (OperationCanceledException)
            {
                throw;
            }
            catch (Exception)
            {
                return HostRuntimeState.DeviceValidationRequired;
            }
        }
        var scale = host.DpiScale;
        var placement = PlacementResolver.Resolve(
            host.Bounds,
            titlebar.PreferredAnchorTrailingEdge,
            IndicatorWidth * scale,
            IndicatorGap * scale,
            titlebar.Obstacles,
            verticalInset: 4 * scale,
            indicatorHeight: 40 * scale);
        if (placement.Surface != PlacementSurface.Content)
        {
            await overlay.HideAsync(cancellationToken).ConfigureAwait(false);
            return HostRuntimeState.Hidden;
        }

        await overlay.ShowAsync(
            new OverlayPresentation(host.Handle, host.DpiScale, snapshot, placement, freshness),
            cancellationToken).ConfigureAwait(false);
        return HostRuntimeState.Visible;
    }
}
