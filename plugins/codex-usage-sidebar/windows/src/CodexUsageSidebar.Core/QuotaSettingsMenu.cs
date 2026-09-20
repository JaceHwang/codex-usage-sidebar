namespace CodexUsageSidebar.Core;

public enum QuotaSettingsAction { Position, CheckUpdates, Reload, Quit }
public sealed record QuotaPlacementMenuItem(string Label, string Icon, IndicatorPlacementMode Mode, bool Selected);
public sealed record QuotaSettingsMenuItem(QuotaSettingsAction Action, string Label, string Icon,
    IReadOnlyList<QuotaPlacementMenuItem>? Children = null);

public static class QuotaSettingsMenu
{
    public static IReadOnlyList<QuotaSettingsMenuItem> Create(DisplayLanguage language, IndicatorPlacementMode mode)
    {
        return
        [
            new(QuotaSettingsAction.Position, Copy(language, "位置模式", "位置模式", "Position Mode"), "\uE707",
                CreatePlacementItems(language, mode)),
            new(QuotaSettingsAction.CheckUpdates, Copy(language, "检查更新", "檢查更新", "Check for Updates"), "\uE896"),
            new(QuotaSettingsAction.Reload, Copy(language, "重新加载", "重新載入", "Reload"), "\uE72C"),
            new(QuotaSettingsAction.Quit, Copy(language, "退出应用", "結束應用程式", "Quit App"), "\uE7E8"),
        ];
    }

    public static IReadOnlyList<QuotaPlacementMenuItem> CreatePlacementItems(
        DisplayLanguage language,
        IndicatorPlacementMode mode) =>
    [
        new(Copy(language, "自动贴合", "自動貼合", "Auto Attach"), "\uE71B",
            IndicatorPlacementMode.Automatic, mode == IndicatorPlacementMode.Automatic),
        new(Copy(language, "自由移动", "自由移動", "Free Move"), "\uE7C9",
            IndicatorPlacementMode.Free, mode == IndicatorPlacementMode.Free),
        new(Copy(language, "锁定位置", "鎖定位置", "Lock Position"), "\uE72E",
            IndicatorPlacementMode.Locked, mode == IndicatorPlacementMode.Locked),
    ];

    private static string Copy(
        DisplayLanguage language,
        string simplified,
        string traditional,
        string english) => language switch
    {
        DisplayLanguage.SimplifiedChinese => simplified,
        DisplayLanguage.TraditionalChinese => traditional,
        _ => english,
    };
}
