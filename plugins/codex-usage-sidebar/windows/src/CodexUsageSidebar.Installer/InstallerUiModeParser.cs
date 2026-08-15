namespace CodexUsageSidebar.Installer;

public static class InstallerUiModeParser
{
    public static InstallerUiMode Parse(IReadOnlyList<string> arguments)
    {
        ArgumentNullException.ThrowIfNull(arguments);
        if (arguments.Count == 0)
        {
            return InstallerUiMode.Install;
        }
        if (arguments.Count != 1)
        {
            throw new ArgumentException("Exactly one installer mode may be specified.", nameof(arguments));
        }
        return arguments[0] switch
        {
            "--repair" => InstallerUiMode.Repair,
            "--uninstall" => InstallerUiMode.Uninstall,
            _ => throw new ArgumentException("The installer mode is not supported.", nameof(arguments)),
        };
    }
}
