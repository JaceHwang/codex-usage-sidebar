namespace CodexUsageSidebar.Installer;

public sealed class FileManagedInstallLock(string installRoot) : IManagedInstallLock
{
    private readonly string root = WindowsPath.Normalize(installRoot);

    public IDisposable Acquire()
    {
        Directory.CreateDirectory(root);
        EnsureNotReparsePoint(root);
        return new FileStream(
            Path.Combine(root, "install.lock"),
            FileMode.OpenOrCreate,
            FileAccess.ReadWrite,
            FileShare.None);
    }

    private static void EnsureNotReparsePoint(string path)
    {
        if ((File.GetAttributes(path) & FileAttributes.ReparsePoint) != 0)
        {
            throw new InvalidDataException("The install root cannot be a link or reparse point.");
        }
    }
}

public sealed class FileManagedPayloadOperations(
    InstallerPathPlan paths,
    DevicePayloadInstallPlan installPlan) : IManagedPayloadOperations
{
    public void Validate()
    {
        AtomicPayloadInstaller.ValidateNoLinks(installPlan.SourcePayload);
        AtomicPayloadInstaller.ValidateManifest(installPlan.SourcePayload, installPlan.TrustedIdentity);
    }

    public void Activate() => installPlan.Install();

    public void RemoveCurrent()
    {
        SafeUninstallGuard.EnsureExactPayload(paths, installPlan.DestinationPayload);
        if (!Directory.Exists(paths.CurrentPayload)) return;
        AtomicPayloadInstaller.ValidateNoLinks(paths.CurrentPayload);

        var tombstone = Path.Combine(
            paths.InstallRoot,
            ".cus-uninstall-" + Guid.NewGuid().ToString("N"));
        Directory.Move(paths.CurrentPayload, tombstone);
        try
        {
            Directory.Delete(tombstone, recursive: true);
        }
        catch
        {
            if (Directory.Exists(tombstone) && !Directory.Exists(paths.CurrentPayload))
            {
                Directory.Move(tombstone, paths.CurrentPayload);
            }
            throw;
        }
    }
}

public static class DeviceTestInstallerRuntimeFactory
{
    public static IInstallerUiActions? TryCreate(
        string managerDirectory,
        string localAppData,
        string architecture,
        int windowsBuild,
        string? sourceCommit,
        string? payloadManifestSha256)
    {
        if (string.IsNullOrWhiteSpace(sourceCommit)
            || string.IsNullOrWhiteSpace(payloadManifestSha256))
        {
            return null;
        }
        if (!OperatingSystem.IsWindows())
        {
            throw new PlatformNotSupportedException("The device-test installer requires Windows 11.");
        }

        var bundle = DeviceTestBundlePlan.Create(
            managerDirectory,
            localAppData,
            architecture,
            windowsBuild,
            sourceCommit,
            payloadManifestSha256);
        var autostartPlan = AutostartPlan.Create(bundle.ManagedHostExecutable);
        return new DeviceTestInstallerUiActions(
            bundle.Paths,
            new FileManagedInstallLock(bundle.Paths.InstallRoot),
            new FileManagedPayloadOperations(bundle.Paths, bundle.InstallPlan),
            new ManagedAutostart(autostartPlan, new WindowsCurrentUserRunStore()),
            new ManagedHostLifecycle(bundle.ManagedHostExecutable, new WindowsManagedProcessCatalog()));
    }
}
