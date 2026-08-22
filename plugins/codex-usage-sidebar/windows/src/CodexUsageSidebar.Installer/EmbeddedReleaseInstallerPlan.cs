namespace CodexUsageSidebar.Installer;

public sealed record EmbeddedReleaseInstallerPlan(
    InstallerPathPlan Paths,
    string PrivateStageParent,
    string ManagedHostExecutable,
    TrustedPayloadIdentity TrustedIdentity)
{
    public static EmbeddedReleaseInstallerPlan Create(
        string localAppData,
        string architecture,
        int windowsBuild,
        string version,
        string sourceCommit,
        string payloadManifestSha256,
        string codexRuntimeSource,
        string codexRuntimeSha256)
    {
        if (!string.Equals(architecture, "x64", StringComparison.Ordinal))
        {
            throw new PlatformNotSupportedException("Windows v0.3.1 releases support AMD64/x64 only.");
        }
        if (windowsBuild < 22_000)
        {
            throw new PlatformNotSupportedException("Windows v0.3.1 releases require Windows 11 build 22000 or newer.");
        }

        var identity = new TrustedPayloadIdentity(
            version,
            sourceCommit,
            codexRuntimeSource,
            codexRuntimeSha256,
            payloadManifestSha256,
            PayloadManifestPolicy.PublishedRelease);
        _ = new AtomicPayloadInstaller(identity);
        var paths = InstallerPathPlan.Create(localAppData);
        return new EmbeddedReleaseInstallerPlan(
            paths,
            WindowsPath.Combine(paths.InstallRoot, "SetupStaging"),
            WindowsPath.Combine(paths.CurrentPayload, "CodexUsageSidebar.Windows.exe"),
            identity);
    }
}
