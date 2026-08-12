namespace CodexUsageSidebar.Installer;

public enum InstallerPayloadMode
{
    Unavailable,
    DeviceTest,
    EmbeddedRelease,
}

public static class InstallerPayloadModeParser
{
    public static InstallerPayloadMode Parse(string? value) => value switch
    {
        null or "" => InstallerPayloadMode.Unavailable,
        "device-test" => InstallerPayloadMode.DeviceTest,
        "embedded-release" => InstallerPayloadMode.EmbeddedRelease,
        _ => throw new InvalidOperationException("The installer payload mode metadata is invalid."),
    };
}
