namespace CodexUsageSidebar.Installer;

public interface IManagedPayloadOperations
{
    void Validate();
    void Activate();
    void RemoveCurrent();
}

public interface IManagedInstallLock
{
    IDisposable Acquire();
}

public interface IManagedAutostart
{
    void Write();
    void RemoveIfOwned();
}

public interface IManagedHostLifecycle
{
    void StopExact();
    void StartExact(IReadOnlyList<string> arguments);
}

public sealed class DeviceTestInstallerUiActions(
    InstallerPathPlan paths,
    IManagedInstallLock installLock,
    IManagedPayloadOperations payload,
    IManagedAutostart autostart,
    IManagedHostLifecycle host) : IInstallerUiActions
{
    public Task ExecuteAsync(InstallerUiMode mode, CancellationToken cancellationToken) =>
        Task.Run(() => Execute(mode, cancellationToken), cancellationToken);

    private void Execute(InstallerUiMode mode, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        if (mode is InstallerUiMode.Install or InstallerUiMode.Repair)
        {
            payload.Validate();
            cancellationToken.ThrowIfCancellationRequested();
        }
        using var operationLock = installLock.Acquire();
        cancellationToken.ThrowIfCancellationRequested();
        host.StopExact();
        cancellationToken.ThrowIfCancellationRequested();

        switch (mode)
        {
            case InstallerUiMode.Install:
            case InstallerUiMode.Repair:
                payload.Activate();
                cancellationToken.ThrowIfCancellationRequested();
                autostart.Write();
                host.StartExact(["--background"]);
                break;
            case InstallerUiMode.Uninstall:
                autostart.RemoveIfOwned();
                SafeUninstallGuard.EnsureExactPayload(paths, paths.CurrentPayload);
                payload.RemoveCurrent();
                break;
            default:
                throw new ArgumentOutOfRangeException(nameof(mode));
        }
    }
}
