namespace CodexUsageSidebar.Windows.Tests;

[TestClass]
public sealed class WindowsRuntimePathsTests
{
    [TestMethod]
    public void UsesOnlyTheVersionedPayloadAndPerUserCodexHome()
    {
        var paths = WindowsRuntimePaths.Create(
            @"C:\Payload\Current",
            @"C:\Users\fixture\AppData\Local");

        Assert.AreEqual(@"C:\Payload\Current\codex.exe", paths.CodexExecutable);
        Assert.AreEqual(
            @"C:\Users\fixture\AppData\Local\CodexUsageSidebar\CodexHome",
            paths.IsolatedCodexHome);
        Assert.ThrowsException<ArgumentException>(() =>
            WindowsRuntimePaths.Create("relative", @"C:\Users\fixture\AppData\Local"));
    }
}
