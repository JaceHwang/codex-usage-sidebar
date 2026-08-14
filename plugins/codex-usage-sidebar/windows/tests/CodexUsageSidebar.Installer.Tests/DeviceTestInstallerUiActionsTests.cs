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

    [TestMethod]
    public async Task InstallFailureIncludesOnlyAnExplicitNestedSafeStage()
    {
        const string sensitiveMessage = @"Access denied at C:\Users\fixture\secret token=do-not-display";
        var cause = new IOException(sensitiveMessage);
        var nested = new InstallerSafeStageException("atomic-install", cause);
        var actions = CreateActions([], "activate", nested);

        var error = await Assert.ThrowsExceptionAsync<InvalidOperationException>(() =>
            actions.ExecuteAsync(InstallerUiMode.Install, CancellationToken.None));

        Assert.AreEqual("Installer phase failed: Payload activation (atomic-install).", error.Message);
        Assert.AreSame(nested, error.InnerException);
        Assert.IsFalse(error.Message.Contains(sensitiveMessage, StringComparison.Ordinal));
    }

    [TestMethod]
    public async Task InstallRetriesOnlyTheTransientPreviousPayloadMoveStageBeforeStartingTheHost()
    {
        var log = new List<string>();
        var payload = new TransientPreviousPayloadMovePayload(log);
        var actions = new DeviceTestInstallerUiActions(
            Paths,
            new RecordingInstallLock(log),
            payload,
            new RecordingAutostart(log),
            new RecordingHost(log));

        await actions.ExecuteAsync(InstallerUiMode.Install, CancellationToken.None);

        Assert.AreEqual(2, payload.ActivationAttempts);
        CollectionAssert.AreEqual(
            new[]
            {
                "validate", "lock-enter", "stop", "activate", "activate",
                "autostart-write", "start:--background", "lock-exit",
            },
            log);
    }

    [TestMethod]
    public async Task InstallDoesNotRetryOtherSafePayloadStages()
    {
        var log = new List<string>();
        var payload = new PersistentSafeStagePayload(log, "atomic-install");
        var actions = new DeviceTestInstallerUiActions(
            Paths,
            new RecordingInstallLock(log),
            payload,
            new RecordingAutostart(log),
            new RecordingHost(log));

        var error = await Assert.ThrowsExceptionAsync<InvalidOperationException>(() =>
            actions.ExecuteAsync(InstallerUiMode.Install, CancellationToken.None));

        Assert.AreEqual("Installer phase failed: Payload activation (atomic-install).", error.Message);
        Assert.AreEqual(1, payload.ActivationAttempts);
        CollectionAssert.AreEqual(
            new[] { "validate", "lock-enter", "stop", "activate", "lock-exit" },
            log);
    }

    [DataTestMethod]
    [DataRow("autostart-remove-owned", "Autostart removal")]
    [DataRow("remove-current", "Payload removal")]
    public async Task UninstallFailuresIdentifyOnlyTheSafePhaseAndPreserveTheCause(
        string failingOperation,
        string phase)
    {
        const string sensitiveMessage = @"Access denied at C:\Users\fixture\secret token=do-not-display";
        var cause = new IOException(sensitiveMessage);
        var actions = CreateActions([], failingOperation, cause);

        var error = await Assert.ThrowsExceptionAsync<InvalidOperationException>(() =>
            actions.ExecuteAsync(InstallerUiMode.Uninstall, CancellationToken.None));

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
        public void RemoveCurrent() => Record("remove-current");

        private void Record(string operation)
        {
            log.Add(operation);
            if (failingOperation == operation)
            {
                throw error!;
            }
        }
    }

    private sealed class TransientPreviousPayloadMovePayload(List<string> log) : IManagedPayloadOperations
    {
        public int ActivationAttempts { get; private set; }

        public void Validate() => log.Add("validate");

        public void Activate()
        {
            log.Add("activate");
            ActivationAttempts++;
            if (ActivationAttempts == 1)
            {
                throw new InstallerSafeStageException("previous-payload-move", new IOException("payload handle is draining"));
            }
        }

        public void RemoveCurrent() => log.Add("remove-current");
    }

    private sealed class PersistentSafeStagePayload(List<string> log, string stage) : IManagedPayloadOperations
    {
        public int ActivationAttempts { get; private set; }

        public void Validate() => log.Add("validate");

        public void Activate()
        {
            log.Add("activate");
            ActivationAttempts++;
            throw new InstallerSafeStageException(stage, new IOException("persistent activation failure"));
        }

        public void RemoveCurrent() => log.Add("remove-current");
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

        public void RemoveIfOwned() => Record("autostart-remove-owned");

        private void Record(string operation)
        {
            log.Add(operation);
            if (failingOperation == operation)
            {
                throw error!;
            }
        }
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
