using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Windows;

public sealed class WindowsHostCoordinator
{
    private const double IndicatorWidth = 208;
    private const double IndicatorGap = 8;
    private readonly IHostWindowLocator locator;
    private readonly ITitlebarScanner scanner;
    private readonly IOverlaySurface overlay;
    private string? lastBuildIdentity;

    public WindowsHostCoordinator(
        IHostWindowLocator locator,
        ITitlebarScanner scanner,
        IOverlaySurface overlay)
    {
        this.locator = locator;
        this.scanner = scanner;
        this.overlay = overlay;
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

        TitlebarSnapshot titlebar;
        try
        {
            titlebar = await scanner.ScanAsync(host, cancellationToken).ConfigureAwait(false);
        }
        catch (WindowsDeviceValidationRequiredException)
        {
            await overlay.HideAsync(cancellationToken).ConfigureAwait(false);
            return HostRuntimeState.DeviceValidationRequired;
        }
        var placement = PlacementResolver.Resolve(
            host.Bounds,
            titlebar.PreferredAnchorTrailingEdge,
            IndicatorWidth,
            IndicatorGap,
            titlebar.Obstacles);
        await overlay.ShowAsync(
            new OverlayPresentation(host.Handle, host.DpiScale, snapshot, placement),
            cancellationToken).ConfigureAwait(false);
        return HostRuntimeState.Visible;
    }
}
