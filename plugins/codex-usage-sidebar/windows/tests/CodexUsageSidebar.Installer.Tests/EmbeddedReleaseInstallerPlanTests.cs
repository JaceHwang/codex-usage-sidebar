namespace CodexUsageSidebar.Installer.Tests;

[TestClass]
public sealed class EmbeddedReleaseInstallerPlanTests
{
    private const string Commit = "0123456789abcdef0123456789abcdef01234567";
    private const string ManifestSha256 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    private const string RuntimeSha256 = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
    private const string RuntimeSource = "https://github.com/openai/codex/releases/download/test/codex.exe";

    [TestMethod]
    public void CreatesAnExactPublishedReleasePlanForWindows11X64()
    {
        var plan = EmbeddedReleaseInstallerPlan.Create(
            @"C:\Users\fixture\AppData\Local",
            "x64",
            22_000,
            "0.3.0",
            Commit,
            ManifestSha256,
            RuntimeSource,
            RuntimeSha256);

        Assert.AreEqual(@"C:\Users\fixture\AppData\Local\CodexUsageSidebar\SetupStaging", plan.PrivateStageParent);
        Assert.AreEqual(@"C:\Users\fixture\AppData\Local\CodexUsageSidebar\Current\CodexUsageSidebar.Windows.exe", plan.ManagedHostExecutable);
        Assert.AreEqual("0.3.0", plan.TrustedIdentity.Version);
        Assert.AreEqual(Commit, plan.TrustedIdentity.SourceCommit);
        Assert.AreEqual(ManifestSha256, plan.TrustedIdentity.PayloadManifestSha256);
        Assert.AreEqual(PayloadManifestPolicy.PublishedRelease, plan.TrustedIdentity.Policy);
    }

    [TestMethod]
    public void RejectsArm64OldWindowsOrIncompleteTrustedMetadata()
    {
        Assert.ThrowsException<PlatformNotSupportedException>(() => Create("arm64", 22_000));
        Assert.ThrowsException<PlatformNotSupportedException>(() => Create("x64", 21_999));
        Assert.ThrowsException<ArgumentException>(() => EmbeddedReleaseInstallerPlan.Create(
            @"C:\Users\fixture\AppData\Local", "x64", 22_000, "0.3.0", "bad", ManifestSha256, RuntimeSource, RuntimeSha256));
        Assert.ThrowsException<ArgumentException>(() => EmbeddedReleaseInstallerPlan.Create(
            @"C:\Users\fixture\AppData\Local", "x64", 22_000, "0.3.0", Commit, "bad", RuntimeSource, RuntimeSha256));
    }

    private static EmbeddedReleaseInstallerPlan Create(string architecture, int windowsBuild) =>
        EmbeddedReleaseInstallerPlan.Create(
            @"C:\Users\fixture\AppData\Local",
            architecture,
            windowsBuild,
            "0.3.0",
            Commit,
            ManifestSha256,
            RuntimeSource,
            RuntimeSha256);
}
