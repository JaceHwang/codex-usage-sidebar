namespace CodexUsageSidebar.Installer.Tests;

[TestClass]
public sealed class InstallerUiControllerTests
{
    [TestMethod]
    public void ParsesOnlyExplicitInstallerModes()
    {
        Assert.AreEqual(InstallerUiMode.Install, InstallerUiModeParser.Parse([]));
        Assert.AreEqual(InstallerUiMode.Repair, InstallerUiModeParser.Parse(["--repair"]));
        Assert.AreEqual(InstallerUiMode.Uninstall, InstallerUiModeParser.Parse(["--uninstall"]));
        Assert.ThrowsException<ArgumentException>(() => InstallerUiModeParser.Parse(["--unknown"]));
    }

    [DataTestMethod]
    [DataRow("zh-Hans-CN", InstallerUiMode.Install, "安装", "安装程序")]
    [DataRow("zh-Hant-TW", InstallerUiMode.Repair, "修復", "安裝程式")]
    [DataRow("en-US", InstallerUiMode.Uninstall, "Uninstall", "Setup")]
    public void LocalizesEveryInstallerMode(
        string locale,
        InstallerUiMode mode,
        string expectedPrimaryAction,
        string expectedTitleFragment)
    {
        var model = InstallerUiModel.Create(locale, mode, InstallerUiState.Ready);

        Assert.AreEqual(expectedPrimaryAction, model.PrimaryAction);
        StringAssert.Contains(model.Title, expectedTitleFragment);
        Assert.IsTrue(model.CanExecute);
        Assert.IsTrue(model.CanCancel);
        var nonpublishable = locale.StartsWith("zh-Hant", StringComparison.Ordinal)
            ? "不可發佈"
            : locale.StartsWith("zh", StringComparison.Ordinal) ? "不可发布" : "not publishable";
        StringAssert.Contains(model.Description, nonpublishable);
    }

    [TestMethod]
    public void UninstallSuccessExplainsThatLocalDataWasPreserved()
    {
        var simplified = InstallerUiModel.Create(
            "zh-Hans-CN",
            InstallerUiMode.Uninstall,
            InstallerUiState.Succeeded);
        var english = InstallerUiModel.Create(
            "en-US",
            InstallerUiMode.Uninstall,
            InstallerUiState.Succeeded);

        StringAssert.Contains(simplified.Status, "已保留本地授权和状态数据");
        StringAssert.Contains(english.Status, "Local authorization and state data were kept");
    }

    [DataTestMethod]
    [DataRow("zh-Hans-CN", InstallerUiMode.Install, "为当前 Windows 用户安装", "不可发布")]
    [DataRow("zh-Hant-TW", InstallerUiMode.Repair, "驗證並修復目前使用者", "不可發佈")]
    [DataRow("en-US", InstallerUiMode.Uninstall, "Uninstall Codex Usage Sidebar", "not publishable")]
    public void PublishedReleaseCopyIsLocalizedWithoutDeviceTestWarnings(
        string locale,
        InstallerUiMode mode,
        string expectedDescription,
        string forbiddenDeviceTestWarning)
    {
        var model = InstallerUiModel.Create(
            locale,
            mode,
            InstallerUiState.Ready,
            flavor: InstallerUiFlavor.PublishedRelease,
            displayVersion: "0.3.2");

        StringAssert.Contains(model.Description, expectedDescription);
        Assert.AreEqual("0.3.2", model.DisplayVersion);
        Assert.IsFalse(model.Description.Contains(forbiddenDeviceTestWarning, StringComparison.OrdinalIgnoreCase));
        Assert.IsFalse(model.Description.Contains("device-test", StringComparison.OrdinalIgnoreCase));
    }

    [DataTestMethod]
    [DataRow("en-US", InstallerRuntimeHealth.InstallRequired, "Installation is required")]
    [DataRow("zh-Hans-CN", InstallerRuntimeHealth.SafeDockVisible, "安全停靠栏")]
    [DataRow("zh-Hant-TW", InstallerRuntimeHealth.ValidationNeeded, "驗證")]
    public void LocalizesPostInstallRuntimeHealth(
        string locale,
        InstallerRuntimeHealth health,
        string expectedStatus)
    {
        var model = InstallerUiModel.Create(
            locale,
            InstallerUiMode.Install,
            InstallerUiState.Succeeded,
            health: health,
            flavor: InstallerUiFlavor.PublishedRelease,
            displayVersion: "0.3.3");

        StringAssert.Contains(model.Status, expectedStatus);
    }

    [TestMethod]
    public async Task RunsTheSelectedOperationOnceAndReportsSuccess()
    {
        var actions = new RecordingActions();
        var controller = new InstallerUiController("en-US", InstallerUiMode.Repair, actions);
        var observedStates = new List<InstallerUiState>();
        controller.Changed += (_, model) => observedStates.Add(model.State);

        await controller.ExecuteAsync(CancellationToken.None);

        CollectionAssert.AreEqual(
            new[] { InstallerUiState.Working, InstallerUiState.Succeeded },
            observedStates);
        Assert.AreEqual(1, actions.CallCount);
        Assert.AreEqual(InstallerUiMode.Repair, actions.LastMode);
        Assert.AreEqual("Repair complete.", controller.Model.Status);
        Assert.IsFalse(controller.Model.CanExecute);
    }

    [DataTestMethod]
    [DataRow(InstallerRuntimeHealth.Healthy, "Installation complete.")]
    [DataRow(InstallerRuntimeHealth.SafeDockVisible, "safe dock is visible")]
    [DataRow(InstallerRuntimeHealth.ValidationNeeded, "Compatibility validation is needed")]
    public async Task InstallFlowWaitsAtMostTenSecondsForEmittedRuntimeHealthAndRendersIt(
        InstallerRuntimeHealth health,
        string expectedStatus)
    {
        var source = new RecordingRuntimeHealthSource(health);
        var controller = new InstallerUiController(
            "en-US", InstallerUiMode.Install, new RecordingActions(),
            InstallerUiFlavor.PublishedRelease, "0.3.3", source);

        await controller.ExecuteAsync(CancellationToken.None);

        Assert.AreEqual(TimeSpan.FromSeconds(10), source.Timeout);
        StringAssert.Contains(controller.Model.Status, expectedStatus);
    }

    [TestMethod]
    public async Task ReportsFailureWithoutRetryingOrChangingTheSelectedMode()
    {
        var actions = new RecordingActions(new InvalidOperationException("payload rejected"));
        var controller = new InstallerUiController("zh-Hans-CN", InstallerUiMode.Uninstall, actions);

        await controller.ExecuteAsync(CancellationToken.None);

        Assert.AreEqual(1, actions.CallCount);
        Assert.AreEqual(InstallerUiMode.Uninstall, controller.Model.Mode);
        Assert.AreEqual(InstallerUiState.Failed, controller.Model.State);
        StringAssert.Contains(controller.Model.Status, "payload rejected");
        Assert.IsTrue(controller.Model.CanExecute);
    }

    private sealed class RecordingActions(Exception? error = null) : IInstallerUiActions
    {
        public int CallCount { get; private set; }
        public InstallerUiMode? LastMode { get; private set; }

        public Task ExecuteAsync(InstallerUiMode mode, CancellationToken cancellationToken)
        {
            CallCount++;
            LastMode = mode;
            return error is null ? Task.CompletedTask : Task.FromException(error);
        }
    }

    private sealed class RecordingRuntimeHealthSource(InstallerRuntimeHealth health) : IInstallerRuntimeHealthSource
    {
        public TimeSpan Timeout { get; private set; }

        public Task<InstallerRuntimeHealth> WaitAsync(TimeSpan timeout, CancellationToken cancellationToken)
        {
            Timeout = timeout;
            return Task.FromResult(health);
        }
    }
}
