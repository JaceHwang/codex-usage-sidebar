using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Windows.Tests;

[TestClass]
public sealed class WindowsCodexLanguageProviderTests
{
    [TestMethod]
    public void RereadsDesktopLocaleOverrideAndFallsBackToSystemWhenItIsMissing()
    {
        var root = Path.Combine(Path.GetTempPath(), "cus-language-" + Guid.NewGuid().ToString("N"));
        var config = Path.Combine(root, "config.toml");
        try
        {
            Directory.CreateDirectory(root);
            var provider = new WindowsCodexLanguageProvider(config, () => "zh-Hans-CN");

            Assert.AreEqual(DisplayLanguage.SimplifiedChinese, provider.CurrentLanguage()?.Language);
            Assert.AreEqual(DisplayLanguageSource.System, provider.CurrentLanguage()?.Source);

            File.WriteAllText(config, "[desktop]\nlocaleOverride = \"en-US\"");
            Assert.AreEqual(DisplayLanguage.English, provider.CurrentLanguage()?.Language);
            Assert.AreEqual(DisplayLanguageSource.Configuration, provider.CurrentLanguage()?.Source);

            File.WriteAllText(config, "[desktop]\nlocaleOverride = \"zh-Hant-TW\"");
            Assert.AreEqual(DisplayLanguage.TraditionalChinese, provider.CurrentLanguage()?.Language);
        }
        finally
        {
            if (Directory.Exists(root))
            {
                Directory.Delete(root, recursive: true);
            }
        }
    }
}
