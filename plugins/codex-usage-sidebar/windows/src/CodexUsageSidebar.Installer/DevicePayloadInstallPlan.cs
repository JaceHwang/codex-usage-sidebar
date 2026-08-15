namespace CodexUsageSidebar.Installer;

public sealed record DevicePayloadInstallPlan(
    string SourcePayload,
    string DestinationPayload,
    TrustedPayloadIdentity TrustedIdentity)
{
    private const string Version = "0.3.0";
    private const string CodexRuntimeSource =
        "https://github.com/openai/codex/releases/download/rust-v0.147.0/codex-x86_64-pc-windows-msvc.exe";
    private const string CodexRuntimeSha256 =
        "935a1911ed2556e4ffcec995f4886ac2ac425863ba26fed264df62e30272ad9d";

    public static DevicePayloadInstallPlan Create(
        string localAppData,
        string sourcePayload,
        string sourceCommit,
        string payloadManifestSha256,
        string architecture,
        int windowsBuild)
    {
        if (!string.Equals(architecture, "x64", StringComparison.Ordinal))
        {
            throw new PlatformNotSupportedException(
                "Windows v0.3.0 device payloads support AMD64/x64 only.");
        }
        if (windowsBuild < 22_000)
        {
            throw new PlatformNotSupportedException(
                "Windows v0.3.0 device payloads require Windows 11 build 22000 or newer.");
        }
        var source = WindowsPath.Normalize(sourcePayload);
        if (sourceCommit.Length != 40 || !sourceCommit.All(character =>
                character is >= '0' and <= '9' or >= 'a' and <= 'f'))
        {
            throw new ArgumentException(
                "The source commit must be a lowercase 40-character Git object ID.",
                nameof(sourceCommit));
        }
        if (payloadManifestSha256.Length != 64 || !payloadManifestSha256.All(character =>
                character is >= '0' and <= '9' or >= 'a' and <= 'f'))
        {
            throw new ArgumentException(
                "The payload manifest digest must be lowercase SHA-256.",
                nameof(payloadManifestSha256));
        }
        var paths = InstallerPathPlan.Create(localAppData);
        return new DevicePayloadInstallPlan(
            source,
            paths.CurrentPayload,
            new TrustedPayloadIdentity(
                Version,
                sourceCommit,
                CodexRuntimeSource,
                CodexRuntimeSha256,
                payloadManifestSha256));
    }

    public void Install() =>
        new AtomicPayloadInstaller(TrustedIdentity).Install(SourcePayload, DestinationPayload);
}
