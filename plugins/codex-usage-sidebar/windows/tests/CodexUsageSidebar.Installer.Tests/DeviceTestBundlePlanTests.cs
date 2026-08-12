namespace CodexUsageSidebar.Installer.Tests;

[TestClass]
public sealed class DeviceTestBundlePlanTests
{
    private const string Commit = "0123456789abcdef0123456789abcdef01234567";
    private const string ManifestDigest =
        "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";

    [TestMethod]
    public void UsesOnlyThePayloadSiblingOfTheDeviceTestManager()
    {
        var plan = DeviceTestBundlePlan.Create(
            @"C:\DeviceTest\manager",
            @"C:\Users\fixture\AppData\Local",
            "x64",
            22631,
            Commit,
            ManifestDigest);

        Assert.AreEqual(@"C:\DeviceTest\manager\payload", plan.InstallPlan.SourcePayload);
        Assert.AreEqual(
            @"C:\Users\fixture\AppData\Local\CodexUsageSidebar\Current",
            plan.Paths.CurrentPayload);
        Assert.AreEqual(
            @"C:\Users\fixture\AppData\Local\CodexUsageSidebar\Current\CodexUsageSidebar.Windows.exe",
            plan.ManagedHostExecutable);
    }

    [DataTestMethod]
    [DataRow("arm64", 22631)]
    [DataRow("x64", 19045)]
    public void RejectsUnsupportedArchitectureAndWindowsBuild(string architecture, int windowsBuild)
    {
        Assert.ThrowsException<PlatformNotSupportedException>(() => DeviceTestBundlePlan.Create(
            @"C:\DeviceTest\manager",
            @"C:\Users\fixture\AppData\Local",
            architecture,
            windowsBuild,
            Commit,
            ManifestDigest));
    }
}
