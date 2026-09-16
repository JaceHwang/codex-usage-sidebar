using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Core.Tests;

[TestClass]
public sealed class QuotaSettingsMenuTests
{
    [DataTestMethod]
    [DataRow(DisplayLanguage.SimplifiedChinese)]
    [DataRow(DisplayLanguage.TraditionalChinese)]
    [DataRow(DisplayLanguage.English)]
    public void MenuHasFourActionsAndOneExclusiveSelectedPlacement(DisplayLanguage language)
    {
        var menu = QuotaSettingsMenu.Create(language, IndicatorPlacementMode.Locked);
        CollectionAssert.AreEqual(new[] { QuotaSettingsAction.Position, QuotaSettingsAction.CheckUpdates,
            QuotaSettingsAction.Reload, QuotaSettingsAction.Quit }, menu.Select(item => item.Action).ToArray());
        Assert.IsTrue(menu.All(item => !string.IsNullOrWhiteSpace(item.Icon)));
        Assert.AreEqual(3, menu[0].Children!.Count);
        Assert.AreEqual(IndicatorPlacementMode.Locked, menu[0].Children!.Single(item => item.Selected).Mode);
        Assert.IsTrue(menu.Skip(1).All(item => item.Children is null));
    }
}
