namespace CodexUsageSidebar.Core;

public enum QuotaSettingsAction { Position, CheckUpdates, Reload, Quit }
public sealed record QuotaPlacementMenuItem(string Label, string Icon, IndicatorPlacementMode Mode, bool Selected);
public sealed record QuotaSettingsMenuItem(QuotaSettingsAction Action, string Label, string Icon,
    IReadOnlyList<QuotaPlacementMenuItem>? Children = null);

public static class QuotaSettingsMenu
{
    public static IReadOnlyList<QuotaSettingsMenuItem> Create(DisplayLanguage language, IndicatorPlacementMode mode)
    {
        string Copy(string simplified, string traditional, string english) => language switch
        {
            DisplayLanguage.SimplifiedChinese => simplified,
            DisplayLanguage.TraditionalChinese => traditional,
            _ => english,
        };
        return
        [
            new(QuotaSettingsAction.Position, Copy("位置模式", "位置模式", "Position Mode"), "\uE707",
            [
                new(Copy("自动贴合", "自動貼合", "Auto Attach"), "\uE71B", IndicatorPlacementMode.Automatic, mode == IndicatorPlacementMode.Automatic),
                new(Copy("自由移动", "自由移動", "Free Move"), "\uE7C9", IndicatorPlacementMode.Free, mode == IndicatorPlacementMode.Free),
                new(Copy("锁定位置", "鎖定位置", "Lock Position"), "\uE72E", IndicatorPlacementMode.Locked, mode == IndicatorPlacementMode.Locked),
            ]),
            new(QuotaSettingsAction.CheckUpdates, Copy("检查更新", "檢查更新", "Check for Updates"), "\uE896"),
            new(QuotaSettingsAction.Reload, Copy("重新加载", "重新載入", "Reload"), "\uE72C"),
            new(QuotaSettingsAction.Quit, Copy("退出应用", "結束應用程式", "Quit App"), "\uE7E8"),
        ];
    }
}
