namespace CodexUsageSidebar.Installer.Tests;

[TestClass]
public sealed class InstallerSafetyPlanTests
{
    [TestMethod]
    public void AutostartPlanUsesPerUserRunKeyAndQuotedAbsoluteExecutable()
    {
        var plan = AutostartPlan.Create(@"C:\Users\fixture\AppData\Local\CodexUsageSidebar\Current\CodexUsageSidebar.Windows.exe");
        Assert.AreEqual(@"Software\Microsoft\Windows\CurrentVersion\Run", plan.RegistryKey);
        Assert.AreEqual("CodexUsageSidebar", plan.ValueName);
        Assert.AreEqual("\"C:\\Users\\fixture\\AppData\\Local\\CodexUsageSidebar\\Current\\CodexUsageSidebar.Windows.exe\" --background", plan.ValueData);
        Assert.ThrowsException<ArgumentException>(() => AutostartPlan.Create("CodexUsageSidebar.Windows.exe"));
    }

    [TestMethod]
    public void UninstallGuardAcceptsOnlyTheExactManagedPayload()
    {
        var paths = InstallerPathPlan.Create(@"C:\Users\fixture\AppData\Local");
        SafeUninstallGuard.EnsureExactPayload(paths, paths.CurrentPayload);
        Assert.ThrowsException<InvalidOperationException>(() =>
            SafeUninstallGuard.EnsureExactPayload(paths, paths.InstallRoot));
        Assert.ThrowsException<InvalidOperationException>(() =>
            SafeUninstallGuard.EnsureExactPayload(paths, @"C:\Users\fixture\AppData\Local"));
    }
}
