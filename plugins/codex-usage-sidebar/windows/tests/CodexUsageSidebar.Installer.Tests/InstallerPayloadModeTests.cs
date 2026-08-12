namespace CodexUsageSidebar.Installer.Tests;

[TestClass]
public sealed class InstallerPayloadModeTests
{
    [TestMethod]
    public void ParsesOnlyExplicitInstallerPayloadModes()
    {
        Assert.AreEqual(InstallerPayloadMode.Unavailable, InstallerPayloadModeParser.Parse(null));
        Assert.AreEqual(InstallerPayloadMode.Unavailable, InstallerPayloadModeParser.Parse(string.Empty));
        Assert.AreEqual(InstallerPayloadMode.DeviceTest, InstallerPayloadModeParser.Parse("device-test"));
        Assert.AreEqual(InstallerPayloadMode.EmbeddedRelease, InstallerPayloadModeParser.Parse("embedded-release"));
        Assert.ThrowsException<InvalidOperationException>(() => InstallerPayloadModeParser.Parse("release"));
        Assert.ThrowsException<InvalidOperationException>(() => InstallerPayloadModeParser.Parse("DEVICE-TEST"));
    }
}
