namespace CodexUsageSidebar.Installer.Tests;

[TestClass]
public sealed class DevicePayloadInstallPlanTests
{
    [TestMethod]
    public void PinsTheX64DevicePayloadToTheCurrentUserAndOfficialRuntime()
    {
        var plan = DevicePayloadInstallPlan.Create(
            @"C:\Users\fixture\AppData\Local",
            @"C:\Temp\payload",
            "0123456789abcdef0123456789abcdef01234567",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            "x64",
            22_000);

        Assert.AreEqual(@"C:\Temp\payload", plan.SourcePayload);
        Assert.AreEqual(
            @"C:\Users\fixture\AppData\Local\CodexUsageSidebar\Current",
            plan.DestinationPayload);
        Assert.AreEqual("0.3.3", plan.TrustedIdentity.Version);
        Assert.AreEqual(
            "https://github.com/openai/codex/releases/download/rust-v0.147.0/codex-x86_64-pc-windows-msvc.exe",
            plan.TrustedIdentity.CodexRuntimeSource);
        Assert.AreEqual(
            "935a1911ed2556e4ffcec995f4886ac2ac425863ba26fed264df62e30272ad9d",
            plan.TrustedIdentity.CodexRuntimeSha256);
        Assert.AreEqual(
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            plan.TrustedIdentity.PayloadManifestSha256);
    }

    [TestMethod]
    public void RejectsArm64RelativePayloadsAndInvalidCommits()
    {
        const string commit = "0123456789abcdef0123456789abcdef01234567";
        const string manifestSha = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
        Assert.ThrowsException<PlatformNotSupportedException>(() =>
            DevicePayloadInstallPlan.Create(@"C:\Users\fixture\AppData\Local", @"C:\Temp\payload", commit, manifestSha, "arm64", 22_000));
        Assert.ThrowsException<PlatformNotSupportedException>(() =>
            DevicePayloadInstallPlan.Create(@"C:\Users\fixture\AppData\Local", @"C:\Temp\payload", commit, manifestSha, "x64", 19_045));
        Assert.ThrowsException<ArgumentException>(() =>
            DevicePayloadInstallPlan.Create(@"C:\Users\fixture\AppData\Local", @"payload", commit, manifestSha, "x64", 22_000));
        Assert.ThrowsException<ArgumentException>(() =>
            DevicePayloadInstallPlan.Create(@"C:\Users\fixture\AppData\Local", @"C:\Temp\payload", "invalid", manifestSha, "x64", 22_000));
        Assert.ThrowsException<ArgumentException>(() =>
            DevicePayloadInstallPlan.Create(@"C:\Users\fixture\AppData\Local", @"C:\Temp\payload", commit, "invalid", "x64", 22_000));
    }
}
