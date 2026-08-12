namespace CodexUsageSidebar.Installer.Tests;

[TestClass]
public sealed class DevicePayloadInstallCommandTests
{
    [TestMethod]
    public void ParsesOnlyTheExactDeviceInstallCommand()
    {
        var plan = DevicePayloadInstallCommand.TryCreate(
            InstallerPayloadMode.DeviceTest,
            ["--device-install", @"C:\Temp\payload"],
            @"C:\Users\fixture\AppData\Local",
            "x64",
            22_000,
            "0123456789abcdef0123456789abcdef01234567",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");

        Assert.IsNotNull(plan);
        Assert.AreEqual(@"C:\Temp\payload", plan.SourcePayload);
        Assert.IsNull(DevicePayloadInstallCommand.TryCreate(InstallerPayloadMode.DeviceTest, [], @"C:\Users\fixture\AppData\Local", "x64", 22_000, null, null));
        Assert.ThrowsException<ArgumentException>(() => DevicePayloadInstallCommand.TryCreate(
            InstallerPayloadMode.DeviceTest,
            ["--device-install", @"C:\Temp\payload", "untrusted-commit"],
            @"C:\Users\fixture\AppData\Local",
            "x64",
            22_000,
            "0123456789abcdef0123456789abcdef01234567",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"));
        Assert.ThrowsException<InvalidOperationException>(() => DevicePayloadInstallCommand.TryCreate(
            InstallerPayloadMode.DeviceTest,
            ["--device-install", @"C:\Temp\payload"],
            @"C:\Users\fixture\AppData\Local",
            "x64",
            22_000,
            null,
            null));
        Assert.ThrowsException<PlatformNotSupportedException>(() => DevicePayloadInstallCommand.TryCreate(
            InstallerPayloadMode.DeviceTest,
            ["--device-install", @"C:\Temp\payload"],
            @"C:\Users\fixture\AppData\Local",
            "arm64",
            22_000,
            "0123456789abcdef0123456789abcdef01234567",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"));
    }

    [TestMethod]
    public void EmbeddedReleaseModeNeverAcceptsAnExternalPayloadPath()
    {
        Assert.ThrowsException<ArgumentException>(() => DevicePayloadInstallCommand.TryCreate(
            InstallerPayloadMode.EmbeddedRelease,
            ["--device-install", @"C:\Temp\payload"],
            @"C:\Users\fixture\AppData\Local",
            "x64",
            22_000,
            "0123456789abcdef0123456789abcdef01234567",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"));
    }
}
