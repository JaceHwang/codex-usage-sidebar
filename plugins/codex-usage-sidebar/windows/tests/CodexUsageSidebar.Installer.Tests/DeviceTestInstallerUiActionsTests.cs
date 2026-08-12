namespace CodexUsageSidebar.Installer.Tests;

[TestClass]
public sealed class DeviceTestInstallerUiActionsTests
{
    private static readonly InstallerPathPlan Paths =
        InstallerPathPlan.Create(@"C:\Users\fixture\AppData\Local");

    [TestMethod]
    public async Task InstallAndRepairUseTheProvenanceBoundPayloadBeforeAutostartAndLaunch()
    {
        foreach (var mode in new[] { InstallerUiMode.Install, InstallerUiMode.Repair })
        {
            var log = new List<string>();
            var actions = CreateActions(log);

            await actions.ExecuteAsync(mode, CancellationToken.None);

            CollectionAssert.AreEqual(
                new[] { "validate", "lock-enter", "stop", "activate", "autostart-write", "start:--background", "lock-exit" },
                log,
                mode.ToString());
        }
    }

    [TestMethod]
    public async Task UninstallRemovesOnlyOwnedRuntimeStateAndPreservesLocalData()
    {
        var log = new List<string>();
        var actions = CreateActions(log);

        await actions.ExecuteAsync(InstallerUiMode.Uninstall, CancellationToken.None);

        CollectionAssert.AreEqual(
            new[] { "lock-enter", "stop", "autostart-remove-owned", "remove-current", "lock-exit" },
            log);
        Assert.IsFalse(log.Contains("remove-codex-home"));
        Assert.IsFalse(log.Contains("remove-state"));
    }

    [TestMethod]
    public async Task CancellationBeforeMutationLeavesTheMachineUntouched()
    {
        var log = new List<string>();
        var actions = CreateActions(log);
        using var cancellation = new CancellationTokenSource();
        cancellation.Cancel();

        await Assert.ThrowsExceptionAsync<TaskCanceledException>(() =>
            actions.ExecuteAsync(InstallerUiMode.Install, cancellation.Token));

        Assert.AreEqual(0, log.Count);
    }

    private static DeviceTestInstallerUiActions CreateActions(List<string> log) => new(
        Paths,
        new RecordingInstallLock(log),
        new RecordingPayload(log),
        new RecordingAutostart(log),
        new RecordingHost(log));

    private sealed class RecordingPayload(List<string> log) : IManagedPayloadOperations
    {
        public void Validate() => log.Add("validate");
        public void Activate() => log.Add("activate");
        public void RemoveCurrent() => log.Add("remove-current");
    }

    private sealed class RecordingInstallLock(List<string> log) : IManagedInstallLock
    {
        public IDisposable Acquire()
        {
            log.Add("lock-enter");
            return new CallbackDisposable(() => log.Add("lock-exit"));
        }
    }

    private sealed class CallbackDisposable(Action dispose) : IDisposable
    {
        public void Dispose() => dispose();
    }

    private sealed class RecordingAutostart(List<string> log) : IManagedAutostart
    {
        public void Write() => log.Add("autostart-write");
        public void RemoveIfOwned() => log.Add("autostart-remove-owned");
    }

    private sealed class RecordingHost(List<string> log) : IManagedHostLifecycle
    {
        public void StopExact() => log.Add("stop");
        public void StartExact(IReadOnlyList<string> arguments) =>
            log.Add("start:" + string.Join(' ', arguments));
    }
}
