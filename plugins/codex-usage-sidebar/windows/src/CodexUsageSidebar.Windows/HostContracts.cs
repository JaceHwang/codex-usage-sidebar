using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Windows;

public sealed record HostWindowSnapshot(
    IntPtr Handle,
    RectD Bounds,
    bool IsForeground,
    double DpiScale,
    string BuildIdentity);

public sealed record TitlebarSnapshot(
    double PreferredAnchorTrailingEdge,
    IReadOnlyList<RectD> Obstacles);

public sealed record OverlayPresentation(
    IntPtr OwnerHandle,
    double DpiScale,
    AllowanceSnapshot Snapshot,
    PlacementResult Placement);

public enum HostRuntimeState
{
    WaitingForCodex,
    DeviceValidationRequired,
    Hidden,
    Visible,
}

public sealed class WindowsDeviceValidationRequiredException : Exception
{
    public WindowsDeviceValidationRequiredException(string buildIdentity)
        : base($"Windows UI Automation selectors are not validated for Codex build {buildIdentity}.") =>
        BuildIdentity = buildIdentity;

    public string BuildIdentity { get; }
}

public interface IHostWindowLocator
{
    ValueTask<HostWindowSnapshot?> FindAsync(CancellationToken cancellationToken);
}

public interface ITitlebarScanner
{
    ValueTask<TitlebarSnapshot> ScanAsync(HostWindowSnapshot host, CancellationToken cancellationToken);
    void Invalidate();
}

public interface IOverlaySurface
{
    ValueTask ShowAsync(OverlayPresentation presentation, CancellationToken cancellationToken);
    ValueTask HideAsync(CancellationToken cancellationToken);
}
