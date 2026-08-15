using Microsoft.Win32;
using System.Runtime.Versioning;

namespace CodexUsageSidebar.Installer;

public interface ICurrentUserRunStore
{
    string? Read(AutostartPlan plan);
    void Write(AutostartPlan plan);
    void Delete(AutostartPlan plan);
}

public sealed class ManagedAutostart(
    AutostartPlan plan,
    ICurrentUserRunStore store) : IManagedAutostart
{
    public void Write() => store.Write(plan);

    public void RemoveIfOwned()
    {
        if (string.Equals(store.Read(plan), plan.ValueData, StringComparison.Ordinal))
        {
            store.Delete(plan);
        }
    }
}

[SupportedOSPlatform("windows")]
public sealed class WindowsCurrentUserRunStore : ICurrentUserRunStore
{
    public string? Read(AutostartPlan plan)
    {
        using var key = Registry.CurrentUser.OpenSubKey(plan.RegistryKey, writable: false);
        return key?.GetValue(plan.ValueName, null, RegistryValueOptions.DoNotExpandEnvironmentNames) as string;
    }

    public void Write(AutostartPlan plan)
    {
        using var key = Registry.CurrentUser.CreateSubKey(plan.RegistryKey, writable: true)
            ?? throw new InvalidOperationException("The current-user autostart key could not be opened.");
        key.SetValue(plan.ValueName, plan.ValueData, RegistryValueKind.String);
    }

    public void Delete(AutostartPlan plan)
    {
        using var key = Registry.CurrentUser.OpenSubKey(plan.RegistryKey, writable: true);
        key?.DeleteValue(plan.ValueName, throwOnMissingValue: false);
    }
}
