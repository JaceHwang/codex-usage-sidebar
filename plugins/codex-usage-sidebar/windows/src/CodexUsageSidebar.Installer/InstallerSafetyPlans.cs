namespace CodexUsageSidebar.Installer;

public sealed record AutostartPlan(
    string RegistryKey,
    string ValueName,
    string ValueData)
{
    public static AutostartPlan Create(string executable)
    {
        var normalized = WindowsPath.Normalize(executable);
        if (!normalized.EndsWith(".exe", StringComparison.OrdinalIgnoreCase))
        {
            throw new ArgumentException("The autostart target must be a Windows executable.", nameof(executable));
        }
        return new AutostartPlan(
            @"Software\Microsoft\Windows\CurrentVersion\Run",
            "CodexUsageSidebar",
            $"\"{normalized}\" --background");
    }
}

public static class SafeUninstallGuard
{
    public static void EnsureExactPayload(InstallerPathPlan paths, string requestedTarget)
    {
        if (!paths.IsExactCurrentPayload(requestedTarget))
        {
            throw new InvalidOperationException("Uninstall is limited to the exact managed payload directory.");
        }
    }
}
