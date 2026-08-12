namespace CodexUsageSidebar.Installer.Tests;

[TestClass]
public sealed class ManagedHostLifecycleTests
{
    [TestMethod]
    public void StopsOnlyProcessesAtTheExactManagedPathAndStartsThatPath()
    {
        const string managed =
            @"C:\Users\fixture\AppData\Local\CodexUsageSidebar\Current\CodexUsageSidebar.Windows.exe";
        var matching = new RecordingProcess(managed);
        var other = new RecordingProcess(@"C:\Other\CodexUsageSidebar.Windows.exe");
        var catalog = new RecordingProcessCatalog(matching, other);
        var lifecycle = new ManagedHostLifecycle(managed, catalog);

        lifecycle.StopExact();
        lifecycle.StartExact(["--background"]);

        Assert.IsTrue(matching.Stopped);
        Assert.IsFalse(other.Stopped);
        Assert.AreEqual(managed, catalog.StartedExecutable);
        CollectionAssert.AreEqual(new[] { "--background" }, catalog.StartedArguments!.ToArray());
    }

    private sealed class RecordingProcess(string executablePath) : IManagedProcess
    {
        public string? ExecutablePath { get; } = executablePath;
        public bool Stopped { get; private set; }
        public void StopTreeAndWait() => Stopped = true;
        public void Dispose() { }
    }

    private sealed class RecordingProcessCatalog(params IManagedProcess[] processes) : IManagedProcessCatalog
    {
        public string? StartedExecutable { get; private set; }
        public IReadOnlyList<string>? StartedArguments { get; private set; }
        public IEnumerable<IManagedProcess> FindByName(string processName) => processes;
        public void Start(string executable, IReadOnlyList<string> arguments)
        {
            StartedExecutable = executable;
            StartedArguments = arguments;
        }
    }
}
