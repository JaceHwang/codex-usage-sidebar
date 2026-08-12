using System.Diagnostics;

namespace CodexUsageSidebar.Installer;

public interface IManagedProcess : IDisposable
{
    string? ExecutablePath { get; }
    void StopTreeAndWait();
}

public interface IManagedProcessCatalog
{
    IEnumerable<IManagedProcess> FindByName(string processName);
    void Start(string executable, IReadOnlyList<string> arguments);
}

public sealed class ManagedHostLifecycle(
    string managedExecutable,
    IManagedProcessCatalog processes) : IManagedHostLifecycle
{
    private readonly string normalizedExecutable = WindowsPath.Normalize(managedExecutable);

    public void StopExact()
    {
        foreach (var process in processes.FindByName("CodexUsageSidebar.Windows"))
        {
            using (process)
            {
                if (process.ExecutablePath is { } candidate
                    && string.Equals(
                        WindowsPath.Normalize(candidate),
                        normalizedExecutable,
                        StringComparison.OrdinalIgnoreCase))
                {
                    process.StopTreeAndWait();
                }
            }
        }
    }

    public void StartExact(IReadOnlyList<string> arguments)
    {
        processes.Start(normalizedExecutable, arguments);
    }
}

public sealed class WindowsManagedProcessCatalog : IManagedProcessCatalog
{
    public IEnumerable<IManagedProcess> FindByName(string processName) =>
        Process.GetProcessesByName(processName).Select(process => new WindowsManagedProcess(process));

    public void Start(string executable, IReadOnlyList<string> arguments)
    {
        var startInfo = new ProcessStartInfo(executable)
        {
            UseShellExecute = false,
            WorkingDirectory = Path.GetDirectoryName(executable),
        };
        foreach (var argument in arguments)
        {
            startInfo.ArgumentList.Add(argument);
        }
        using var process = Process.Start(startInfo)
            ?? throw new InvalidOperationException("The managed Windows host did not start.");
    }

    private sealed class WindowsManagedProcess(Process process) : IManagedProcess
    {
        public string? ExecutablePath
        {
            get
            {
                try { return process.MainModule?.FileName; }
                catch (InvalidOperationException) { return null; }
                catch (System.ComponentModel.Win32Exception) { return null; }
            }
        }

        public void StopTreeAndWait()
        {
            if (process.HasExited) return;
            process.Kill(entireProcessTree: true);
            if (!process.WaitForExit(10_000))
            {
                throw new TimeoutException("The managed Windows host did not stop within ten seconds.");
            }
        }

        public void Dispose() => process.Dispose();
    }
}
