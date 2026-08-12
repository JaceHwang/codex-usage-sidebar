namespace CodexUsageSidebar.Installer.Tests;

[TestClass]
public sealed class ManagedAutostartTests
{
    private const string Executable =
        @"C:\Users\fixture\AppData\Local\CodexUsageSidebar\Current\CodexUsageSidebar.Windows.exe";

    [TestMethod]
    public void WritesTheExactPerUserPlan()
    {
        var store = new RecordingRegistryStore();
        var autostart = new ManagedAutostart(AutostartPlan.Create(Executable), store);

        autostart.Write();

        Assert.AreEqual(AutostartPlan.Create(Executable), store.Written);
    }

    [TestMethod]
    public void RemovesOnlyAnExactlyOwnedRunValue()
    {
        var plan = AutostartPlan.Create(Executable);
        var owned = new RecordingRegistryStore { Current = plan.ValueData };
        var foreign = new RecordingRegistryStore { Current = "another command" };

        new ManagedAutostart(plan, owned).RemoveIfOwned();
        new ManagedAutostart(plan, foreign).RemoveIfOwned();

        Assert.IsTrue(owned.Deleted);
        Assert.IsFalse(foreign.Deleted);
    }

    private sealed class RecordingRegistryStore : ICurrentUserRunStore
    {
        public string? Current { get; init; }
        public AutostartPlan? Written { get; private set; }
        public bool Deleted { get; private set; }
        public string? Read(AutostartPlan plan) => Current;
        public void Write(AutostartPlan plan) => Written = plan;
        public void Delete(AutostartPlan plan) => Deleted = true;
    }
}
