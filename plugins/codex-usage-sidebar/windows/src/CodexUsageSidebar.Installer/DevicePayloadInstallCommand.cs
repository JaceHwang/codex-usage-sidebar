namespace CodexUsageSidebar.Installer;

public static class DevicePayloadInstallCommand
{
    public static DevicePayloadInstallPlan? TryCreate(
        IReadOnlyList<string> arguments,
        string localAppData,
        string architecture,
        int windowsBuild,
        string? trustedSourceCommit,
        string? trustedPayloadManifestSha256)
    {
        if (arguments.Count == 0
            || !string.Equals(arguments[0], "--device-install", StringComparison.Ordinal))
        {
            return null;
        }
        if (arguments.Count != 2)
        {
            throw new ArgumentException(
                "Device installation requires exactly one absolute payload path.",
                nameof(arguments));
        }
        if (string.IsNullOrWhiteSpace(trustedSourceCommit)
            || string.IsNullOrWhiteSpace(trustedPayloadManifestSha256))
        {
            throw new InvalidOperationException(
                "This installer was not built for a provenance-bound device payload.");
        }
        return DevicePayloadInstallPlan.Create(
            localAppData,
            arguments[1],
            trustedSourceCommit,
            trustedPayloadManifestSha256,
            architecture,
            windowsBuild);
    }
}
