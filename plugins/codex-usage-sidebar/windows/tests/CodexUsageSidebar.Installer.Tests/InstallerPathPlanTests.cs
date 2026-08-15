namespace CodexUsageSidebar.Installer.Tests;

[TestClass]
public sealed class InstallerPathPlanTests
{
    [TestMethod]
    public void DerivesEveryPerUserTargetFromLocalAppData()
    {
        var plan = InstallerPathPlan.Create(@"C:\Users\fixture\AppData\Local\");

        Assert.AreEqual(@"C:\Users\fixture\AppData\Local\CodexUsageSidebar", plan.InstallRoot);
        Assert.AreEqual(@"C:\Users\fixture\AppData\Local\CodexUsageSidebar\Current", plan.CurrentPayload);
        Assert.AreEqual(@"C:\Users\fixture\AppData\Local\CodexUsageSidebar\CodexHome", plan.IsolatedCodexHome);
        Assert.AreEqual(@"C:\Users\fixture\AppData\Local\CodexUsageSidebar\State", plan.StateDirectory);
    }

    [TestMethod]
    public void NormalizesCaseDotsAndSeparatorsForDestructiveTargetComparison()
    {
        var plan = InstallerPathPlan.Create(@"c:/Users/fixture/AppData/Local");
        Assert.IsTrue(plan.IsExactCurrentPayload(@"C:\Users\fixture\AppData\Local\.\CodexUsageSidebar\Current\"));
        Assert.IsFalse(plan.IsExactCurrentPayload(@"C:\Users\fixture\AppData\Local\CodexUsageSidebar-Other\Current"));
        Assert.ThrowsException<ArgumentException>(() => InstallerPathPlan.Create(@"AppData\Local"));
    }
}
