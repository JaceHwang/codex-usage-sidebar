namespace CodexUsageSidebar.Windows;

public static class WindowsControlCommands
{
    public static string Status(RuntimeStateOutcome? outcome, bool runtimeRunning)
    {
        if (!runtimeRunning) return "runtime=stopped";
        if (outcome is null) return "runtime=running state=unknown";
        return $"runtime=running state={outcome.RuntimeState} placement={outcome.Decision.Placement} reason={outcome.Decision.FailureCode}";
    }
}
