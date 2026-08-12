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
}
