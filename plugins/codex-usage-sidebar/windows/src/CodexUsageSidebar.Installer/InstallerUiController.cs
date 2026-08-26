namespace CodexUsageSidebar.Installer;

public enum InstallerUiMode
{
    Install,
    Repair,
    Uninstall,
}

public enum InstallerUiState
{
    Ready,
    Working,
    Succeeded,
    Failed,
}

public enum InstallerUiFlavor
{
    DeviceTest,
    PublishedRelease,
}

public sealed record InstallerUiModel(
    InstallerUiMode Mode,
    InstallerUiState State,
    string DisplayVersion,
    string Title,
    string Description,
    string PrimaryAction,
    string CancelAction,
    string Status,
    bool CanExecute,
    bool CanCancel)
{
    public static InstallerUiModel Create(
        string? locale,
        InstallerUiMode mode,
        InstallerUiState state,
        string? error = null,
        InstallerUiFlavor flavor = InstallerUiFlavor.DeviceTest,
        string displayVersion = "0.3.3")
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(displayVersion);
        var language = ResolveLanguage(locale);
        var copy = Copy.For(language, mode, flavor);
        var status = state switch
        {
            InstallerUiState.Ready => copy.Ready,
            InstallerUiState.Working => copy.Working,
            InstallerUiState.Succeeded => copy.Succeeded,
            InstallerUiState.Failed => copy.Failed + (string.IsNullOrWhiteSpace(error) ? string.Empty : " " + error),
            _ => throw new ArgumentOutOfRangeException(nameof(state)),
        };
        return new InstallerUiModel(
            mode,
            state,
            displayVersion,
            copy.Title,
            copy.Description,
            copy.Primary,
            copy.Cancel,
            status,
            state is InstallerUiState.Ready or InstallerUiState.Failed,
            state != InstallerUiState.Working);
    }

    private static InstallerLanguage ResolveLanguage(string? locale)
    {
        var normalized = (locale ?? string.Empty).Replace('_', '-').ToLowerInvariant();
        if (!normalized.StartsWith("zh", StringComparison.Ordinal))
        {
            return InstallerLanguage.English;
        }
        return normalized.Contains("hant", StringComparison.Ordinal)
            || normalized.Contains("-tw", StringComparison.Ordinal)
            || normalized.Contains("-hk", StringComparison.Ordinal)
            || normalized.Contains("-mo", StringComparison.Ordinal)
                ? InstallerLanguage.TraditionalChinese
                : InstallerLanguage.SimplifiedChinese;
    }

    private enum InstallerLanguage
    {
        SimplifiedChinese,
        TraditionalChinese,
        English,
    }

    private sealed record Copy(
        string Title,
        string Description,
        string Primary,
        string Cancel,
        string Ready,
        string Working,
        string Succeeded,
        string Failed)
    {
        public static Copy For(
            InstallerLanguage language,
            InstallerUiMode mode,
            InstallerUiFlavor flavor)
        {
            Copy copy = (language, mode) switch
            {
                (InstallerLanguage.SimplifiedChinese, InstallerUiMode.Install) => new(
                    "Codex Usage Sidebar 安装程序", "本机设备测试版本（不可发布）。为当前 Windows 用户安装 Codex Usage Sidebar。",
                    "安装", "取消", "准备安装。", "正在安装…", "安装完成。", "操作失败："),
                (InstallerLanguage.SimplifiedChinese, InstallerUiMode.Repair) => new(
                    "Codex Usage Sidebar 安装程序", "本机设备测试版本（不可发布）。验证并修复当前用户的安装。",
                    "修复", "取消", "准备修复。", "正在修复…", "修复完成。", "操作失败："),
                (InstallerLanguage.SimplifiedChinese, InstallerUiMode.Uninstall) => new(
                    "Codex Usage Sidebar 安装程序", "本机设备测试版本（不可发布）。从当前 Windows 用户卸载 Codex Usage Sidebar。",
                    "卸载", "取消", "准备卸载。", "正在卸载…", "卸载完成。已保留本地授权和状态数据。", "操作失败："),
                (InstallerLanguage.TraditionalChinese, InstallerUiMode.Install) => new(
                    "Codex Usage Sidebar 安裝程式", "本機裝置測試版本（不可發佈）。為目前 Windows 使用者安裝 Codex Usage Sidebar。",
                    "安裝", "取消", "準備安裝。", "正在安裝…", "安裝完成。", "操作失敗："),
                (InstallerLanguage.TraditionalChinese, InstallerUiMode.Repair) => new(
                    "Codex Usage Sidebar 安裝程式", "本機裝置測試版本（不可發佈）。驗證並修復目前使用者的安裝。",
                    "修復", "取消", "準備修復。", "正在修復…", "修復完成。", "操作失敗："),
                (InstallerLanguage.TraditionalChinese, InstallerUiMode.Uninstall) => new(
                    "Codex Usage Sidebar 安裝程式", "本機裝置測試版本（不可發佈）。從目前 Windows 使用者解除安裝 Codex Usage Sidebar。",
                    "解除安裝", "取消", "準備解除安裝。", "正在解除安裝…", "解除安裝完成。已保留本機授權和狀態資料。", "操作失敗："),
                (InstallerLanguage.English, InstallerUiMode.Install) => new(
                    "Codex Usage Sidebar Setup", "Local device-test build (not publishable). Install Codex Usage Sidebar for the current Windows user.",
                    "Install", "Cancel", "Ready to install.", "Installing…", "Installation complete.", "Operation failed:"),
                (InstallerLanguage.English, InstallerUiMode.Repair) => new(
                    "Codex Usage Sidebar Setup", "Local device-test build (not publishable). Verify and repair the current user's installation.",
                    "Repair", "Cancel", "Ready to repair.", "Repairing…", "Repair complete.", "Operation failed:"),
                _ => new(
                    "Codex Usage Sidebar Setup", "Local device-test build (not publishable). Uninstall Codex Usage Sidebar for the current Windows user.",
                    "Uninstall", "Cancel", "Ready to uninstall.", "Uninstalling…", "Uninstall complete. Local authorization and state data were kept.", "Operation failed:"),
            };
            if (flavor == InstallerUiFlavor.DeviceTest) return copy;
            if (flavor != InstallerUiFlavor.PublishedRelease)
            {
                throw new ArgumentOutOfRangeException(nameof(flavor));
            }
            var description = (language, mode) switch
            {
                (InstallerLanguage.SimplifiedChinese, InstallerUiMode.Install) =>
                    "为当前 Windows 用户安装 Codex Usage Sidebar。",
                (InstallerLanguage.SimplifiedChinese, InstallerUiMode.Repair) =>
                    "验证并修复当前用户的 Codex Usage Sidebar 安装。",
                (InstallerLanguage.SimplifiedChinese, InstallerUiMode.Uninstall) =>
                    "从当前 Windows 用户卸载 Codex Usage Sidebar。",
                (InstallerLanguage.TraditionalChinese, InstallerUiMode.Install) =>
                    "為目前 Windows 使用者安裝 Codex Usage Sidebar。",
                (InstallerLanguage.TraditionalChinese, InstallerUiMode.Repair) =>
                    "驗證並修復目前使用者的 Codex Usage Sidebar 安裝。",
                (InstallerLanguage.TraditionalChinese, InstallerUiMode.Uninstall) =>
                    "從目前 Windows 使用者解除安裝 Codex Usage Sidebar。",
                (InstallerLanguage.English, InstallerUiMode.Install) =>
                    "Install Codex Usage Sidebar for the current Windows user.",
                (InstallerLanguage.English, InstallerUiMode.Repair) =>
                    "Verify and repair the current user's Codex Usage Sidebar installation.",
                _ => "Uninstall Codex Usage Sidebar for the current Windows user.",
            };
            return copy with { Description = description };
        }
    }
}

public interface IInstallerUiActions
{
    Task ExecuteAsync(InstallerUiMode mode, CancellationToken cancellationToken);
}

public sealed class InstallerUiController
{
    private readonly string? locale;
    private readonly InstallerUiFlavor flavor;
    private readonly string displayVersion;
    private readonly IInstallerUiActions actions;
    private int isExecuting;

    public InstallerUiController(
        string? locale,
        InstallerUiMode mode,
        IInstallerUiActions actions,
        InstallerUiFlavor flavor = InstallerUiFlavor.DeviceTest,
        string displayVersion = "0.3.3")
    {
        this.locale = locale;
        this.flavor = flavor;
        this.displayVersion = displayVersion;
        this.actions = actions;
        Model = InstallerUiModel.Create(
            locale, mode, InstallerUiState.Ready, flavor: flavor, displayVersion: displayVersion);
    }

    public InstallerUiModel Model { get; private set; }
    public event Action<object?, InstallerUiModel>? Changed;

    public async Task ExecuteAsync(CancellationToken cancellationToken)
    {
        if (Interlocked.Exchange(ref isExecuting, 1) != 0)
        {
            return;
        }
        try
        {
            Update(InstallerUiState.Working);
            await actions.ExecuteAsync(Model.Mode, cancellationToken).ConfigureAwait(false);
            Update(InstallerUiState.Succeeded);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            Update(InstallerUiState.Ready);
            throw;
        }
        catch (Exception error)
        {
            Update(InstallerUiState.Failed, error.Message);
        }
        finally
        {
            Volatile.Write(ref isExecuting, 0);
        }
    }

    private void Update(InstallerUiState state, string? error = null)
    {
        Model = InstallerUiModel.Create(locale, Model.Mode, state, error, flavor, displayVersion);
        Changed?.Invoke(this, Model);
    }
}
