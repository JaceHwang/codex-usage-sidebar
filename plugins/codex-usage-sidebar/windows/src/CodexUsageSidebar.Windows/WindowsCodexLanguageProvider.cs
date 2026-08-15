using System.Globalization;
using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Windows;

internal sealed class WindowsCodexLanguageProvider
{
    private readonly string configurationPath;
    private readonly Func<string> systemLocale;

    internal WindowsCodexLanguageProvider(
        string configurationPath,
        Func<string>? systemLocale = null)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(configurationPath);
        this.configurationPath = configurationPath;
        this.systemLocale = systemLocale ?? (() => CultureInfo.CurrentUICulture.Name);
    }

    internal static WindowsCodexLanguageProvider CreateDefault()
    {
        var profile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        return new WindowsCodexLanguageProvider(Path.Combine(profile, ".codex", "config.toml"));
    }

    internal ResolvedDisplayLanguage? CurrentLanguage()
    {
        string? configurationLocale = null;
        try
        {
            if (File.Exists(configurationPath))
            {
                configurationLocale = CodexConfigurationLanguageParser.LocaleIdentifier(
                    File.ReadAllText(configurationPath));
            }
        }
        catch (IOException)
        {
        }
        catch (UnauthorizedAccessException)
        {
        }

        return LanguageResolver.Resolve(
            configurationLocale: configurationLocale,
            systemLocale: systemLocale());
    }
}
