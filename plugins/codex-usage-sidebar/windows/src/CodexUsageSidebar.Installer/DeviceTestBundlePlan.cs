namespace CodexUsageSidebar.Installer;

public sealed record DeviceTestBundlePlan(
    InstallerPathPlan Paths,
    DevicePayloadInstallPlan InstallPlan,
    string ManagedHostExecutable)
{
    public static DeviceTestBundlePlan Create(
        string managerDirectory,
        string localAppData,
        string architecture,
        int windowsBuild,
        string sourceCommit,
        string payloadManifestSha256)
    {
        var manager = WindowsPath.Normalize(managerDirectory);
        var payload = WindowsPath.Combine(manager, "payload");
        var installPlan = DevicePayloadInstallPlan.Create(
            localAppData,
            payload,
            sourceCommit,
            payloadManifestSha256,
            architecture,
            windowsBuild);
        var paths = InstallerPathPlan.Create(localAppData);
        return new DeviceTestBundlePlan(
            paths,
            installPlan,
            WindowsPath.Combine(paths.CurrentPayload, "CodexUsageSidebar.Windows.exe"));
    }
}
