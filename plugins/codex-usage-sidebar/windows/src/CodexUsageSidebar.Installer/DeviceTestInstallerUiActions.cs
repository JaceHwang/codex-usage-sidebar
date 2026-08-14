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

public sealed class InstallerSafeStageException : Exception
{
    public InstallerSafeStageException(string stage, Exception innerException)
        : base($"Installer safe stage failed: {stage}.", innerException)
    {
        if (string.IsNullOrWhiteSpace(stage)
            || stage.Any(character => character is not (>= 'a' and <= 'z') and not '-'))
        {
            throw new ArgumentException("Installer safe stage must use lowercase ASCII letters and hyphens.", nameof(stage));
        }
        Stage = stage;
    }

    public string Stage { get; }
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
            RunPhase("Payload validation", payload.Validate);
            cancellationToken.ThrowIfCancellationRequested();
        }
        using var operationLock = RunPhase("Operation lock acquisition", installLock.Acquire);
        cancellationToken.ThrowIfCancellationRequested();
        RunPhase("Managed host stop", host.StopExact);
        cancellationToken.ThrowIfCancellationRequested();

        switch (mode)
        {
            case InstallerUiMode.Install:
            case InstallerUiMode.Repair:
                RunPhase("Payload activation", payload.Activate);
                cancellationToken.ThrowIfCancellationRequested();
                RunPhase("Autostart write", autostart.Write);
                RunPhase("Managed host start", () => host.StartExact(["--background"]));
                break;
            case InstallerUiMode.Uninstall:
                RunPhase("Autostart removal", autostart.RemoveIfOwned);
                RunPhase("Payload removal", () =>
                {
                    SafeUninstallGuard.EnsureExactPayload(paths, paths.CurrentPayload);
                    payload.RemoveCurrent();
                });
                break;
            default:
                throw new ArgumentOutOfRangeException(nameof(mode));
        }
    }

    private static void RunPhase(string phase, Action action)
    {
        try
        {
            action();
        }
        catch (InstallerSafeStageException error)
        {
            throw new InvalidOperationException($"Installer phase failed: {phase} ({error.Stage}).", error);
        }
        catch (Exception error) when (error is not OperationCanceledException)
        {
            throw new InvalidOperationException($"Installer phase failed: {phase}.", error);
        }
    }

    private static T RunPhase<T>(string phase, Func<T> action)
    {
        try
        {
            return action();
        }
        catch (InstallerSafeStageException error)
        {
            throw new InvalidOperationException($"Installer phase failed: {phase} ({error.Stage}).", error);
        }
        catch (Exception error) when (error is not OperationCanceledException)
        {
            throw new InvalidOperationException($"Installer phase failed: {phase}.", error);
        }
    }
}
