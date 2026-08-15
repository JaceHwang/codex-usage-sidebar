namespace CodexUsageSidebar.Installer.Tests;

[TestClass]
public sealed class FileManagedPayloadOperationsTests
{
    [TestMethod]
    public void UninstallRemovesCurrentButPreservesCodexHomeAndState()
    {
        var fixture = Path.Combine(Path.GetTempPath(), "cus-installer-" + Guid.NewGuid().ToString("N"));
        try
        {
            var paths = InstallerPathPlan.Create(fixture);
            Directory.CreateDirectory(paths.CurrentPayload);
            Directory.CreateDirectory(paths.IsolatedCodexHome);
            Directory.CreateDirectory(paths.StateDirectory);
            File.WriteAllText(Path.Combine(paths.CurrentPayload, "host.txt"), "managed");
            File.WriteAllText(Path.Combine(paths.IsolatedCodexHome, "auth.txt"), "preserve");
            File.WriteAllText(Path.Combine(paths.StateDirectory, "state.txt"), "preserve");
            var identity = new TrustedPayloadIdentity(
                "0.3.0",
                "0123456789abcdef0123456789abcdef01234567",
                "https://github.com/openai/codex/releases/download/test/codex.exe",
                "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef");
            var plan = new DevicePayloadInstallPlan("C:\\unused", paths.CurrentPayload, identity);

            new FileManagedPayloadOperations(paths, plan).RemoveCurrent();

            Assert.IsFalse(Directory.Exists(paths.CurrentPayload));
            Assert.IsTrue(File.Exists(Path.Combine(paths.IsolatedCodexHome, "auth.txt")));
            Assert.IsTrue(File.Exists(Path.Combine(paths.StateDirectory, "state.txt")));
        }
        finally
        {
            if (Directory.Exists(fixture)) Directory.Delete(fixture, recursive: true);
        }
    }
}
