namespace CodexUsageSidebar.Installer.Tests;

[TestClass]
public sealed class EmbeddedReleaseVerificationCommandTests
{
    [TestMethod]
    public void RunsOnlyTheExactReadOnlyCommandInEmbeddedReleaseMode()
    {
        var calls = 0;

        Assert.IsTrue(EmbeddedReleaseVerificationCommand.TryRun(
            InstallerPayloadMode.EmbeddedRelease,
            ["--verify-embedded"],
            () => calls++));
        Assert.AreEqual(1, calls);
        Assert.IsFalse(EmbeddedReleaseVerificationCommand.TryRun(
            InstallerPayloadMode.EmbeddedRelease,
            [],
            () => calls++));
        Assert.AreEqual(1, calls);

        Assert.ThrowsException<ArgumentException>(() => EmbeddedReleaseVerificationCommand.TryRun(
            InstallerPayloadMode.DeviceTest,
            ["--verify-embedded"],
            () => calls++));
        Assert.ThrowsException<ArgumentException>(() => EmbeddedReleaseVerificationCommand.TryRun(
            InstallerPayloadMode.EmbeddedRelease,
            ["--verify-embedded", "unexpected"],
            () => calls++));
        Assert.AreEqual(1, calls);
    }
}
