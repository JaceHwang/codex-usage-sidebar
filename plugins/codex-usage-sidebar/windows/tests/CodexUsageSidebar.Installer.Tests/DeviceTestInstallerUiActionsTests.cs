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

    [DataTestMethod]
    [DataRow("validate", "Payload validation")]
    [DataRow("lock-enter", "Operation lock acquisition")]
    [DataRow("stop", "Managed host stop")]
    [DataRow("activate", "Payload activation")]
    [DataRow("autostart-write", "Autostart write")]
    [DataRow("start", "Managed host start")]
    public async Task InstallFailuresIdentifyOnlyTheSafePhaseAndPreserveTheCause(
        string failingOperation,
        string phase)
    {
        const string sensitiveMessage = @"Access denied at C:\Users\fixture\secret token=do-not-display";
        var cause = new IOException(sensitiveMessage);
        var actions = CreateActions([], failingOperation, cause);

        var error = await Assert.ThrowsExceptionAsync<InvalidOperationException>(() =>
            actions.ExecuteAsync(InstallerUiMode.Install, CancellationToken.None));

        Assert.AreEqual($"Installer phase failed: {phase}.", error.Message);
        Assert.AreSame(cause, error.InnerException);
        Assert.IsFalse(error.Message.Contains(sensitiveMessage, StringComparison.Ordinal));
    }

    private static DeviceTestInstallerUiActions CreateActions(
        List<string> log,
        string? failingOperation = null,
        Exception? error = null) => new(
        Paths,
        new RecordingInstallLock(log, failingOperation, error),
        new RecordingPayload(log, failingOperation, error),
        new RecordingAutostart(log, failingOperation, error),
        new RecordingHost(log, failingOperation, error));

    private sealed class RecordingPayload(
        List<string> log,
        string? failingOperation = null,
        Exception? error = null) : IManagedPayloadOperations
    {
        public void Validate() => Record("validate");
        public void Activate() => Record("activate");
        public void RemoveCurrent() => log.Add("remove-current");

        private void Record(string operation)
        {
            log.Add(operation);
            if (failingOperation == operation)
            {
                throw error!;
            }
        }
    }

    private sealed class RecordingInstallLock(
        List<string> log,
        string? failingOperation = null,
        Exception? error = null) : IManagedInstallLock
    {
        public IDisposable Acquire()
        {
            log.Add("lock-enter");
            if (failingOperation == "lock-enter")
            {
                throw error!;
            }
            return new CallbackDisposable(() => log.Add("lock-exit"));
        }
    }

    private sealed class CallbackDisposable(Action dispose) : IDisposable
    {
        public void Dispose() => dispose();
    }

    private sealed class RecordingAutostart(
        List<string> log,
        string? failingOperation = null,
        Exception? error = null) : IManagedAutostart
    {
        public void Write()
        {
            log.Add("autostart-write");
            if (failingOperation == "autostart-write")
            {
                throw error!;
            }
        }

        public void RemoveIfOwned() => log.Add("autostart-remove-owned");
    }

    private sealed class RecordingHost(
        List<string> log,
        string? failingOperation = null,
        Exception? error = null) : IManagedHostLifecycle
    {
        public void StopExact()
        {
            log.Add("stop");
            if (failingOperation == "stop")
            {
                throw error!;
            }
        }

        public void StartExact(IReadOnlyList<string> arguments)
        {
            log.Add("start:" + string.Join(' ', arguments));
            if (failingOperation == "start")
            {
                throw error!;
            }
        }
    }
}
