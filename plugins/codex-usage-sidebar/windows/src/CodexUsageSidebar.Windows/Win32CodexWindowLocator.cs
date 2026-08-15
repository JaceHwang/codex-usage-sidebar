#if WINDOWS
using System.Diagnostics;
using System.Runtime.InteropServices;
using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Windows;

public sealed class Win32CodexWindowLocator : IHostWindowLocator
{
    public ValueTask<HostWindowSnapshot?> FindAsync(CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        var foreground = NativeMethods.GetForegroundWindow();
        var candidates = new List<(HostWindowSnapshot Snapshot, double Area)>();
        NativeMethods.EnumWindows((handle, _) =>
        {
            if (!NativeMethods.IsWindowVisible(handle)
                || !NativeMethods.GetWindowRect(handle, out var rectangle))
            {
                return true;
            }
            NativeMethods.GetWindowThreadProcessId(handle, out var processId);
            try
            {
                using var process = Process.GetProcessById(checked((int)processId));
                var versionInfo = SafeFileVersionInfo(process);
                var executablePath = SafeExecutablePath(process);
                if (!CodexProcessIdentity.IsSupported(
                    process.ProcessName,
                    versionInfo?.ProductName,
                    versionInfo?.CompanyName,
                    executablePath,
                    Path.Combine(
                        Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
                        "WindowsApps")))
                {
                    return true;
                }
                var width = Math.Max(0, rectangle.Right - rectangle.Left);
                var height = Math.Max(0, rectangle.Bottom - rectangle.Top);
                if (width < 400 || height < 300)
                {
                    return true;
                }
                var version = versionInfo?.FileVersion ?? "unknown";
                var dpiScale = Math.Max(1, NativeMethods.GetDpiForWindow(handle)) / 96d;
                candidates.Add((new HostWindowSnapshot(
                    handle,
                    new RectD(rectangle.Left, rectangle.Top, width, height),
                    handle == foreground,
                    dpiScale,
                    version), width * height));
            }
            catch (ArgumentException)
            {
            }
            catch (InvalidOperationException)
            {
            }
            return true;
        }, IntPtr.Zero);

        var selected = candidates
            .OrderByDescending(x => x.Snapshot.IsForeground)
            .ThenByDescending(x => x.Area)
            .Select(x => x.Snapshot)
            .FirstOrDefault();
        return ValueTask.FromResult<HostWindowSnapshot?>(selected);
    }

    internal static string? ExecutablePath(IntPtr handle)
    {
        NativeMethods.GetWindowThreadProcessId(handle, out var processId);
        try
        {
            using var process = Process.GetProcessById(checked((int)processId));
            return process.MainModule?.FileName;
        }
        catch (Exception error) when (error is ArgumentException or InvalidOperationException or System.ComponentModel.Win32Exception)
        {
            return null;
        }
    }

    private static FileVersionInfo? SafeFileVersionInfo(Process process)
    {
        try
        {
            return process.MainModule?.FileVersionInfo;
        }
        catch (Exception error) when (error is InvalidOperationException or System.ComponentModel.Win32Exception)
        {
            return null;
        }
    }

    private static string? SafeExecutablePath(Process process)
    {
        try
        {
            return process.MainModule?.FileName;
        }
        catch (Exception error) when (error is InvalidOperationException or System.ComponentModel.Win32Exception)
        {
            return null;
        }
    }

    private static class NativeMethods
    {
        internal delegate bool EnumWindowsCallback(IntPtr handle, IntPtr parameter);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool EnumWindows(EnumWindowsCallback callback, IntPtr parameter);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool IsWindowVisible(IntPtr handle);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool GetWindowRect(IntPtr handle, out NativeRect rectangle);

        [DllImport("user32.dll")]
        internal static extern uint GetWindowThreadProcessId(IntPtr handle, out uint processId);

        [DllImport("user32.dll")]
        internal static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll")]
        internal static extern uint GetDpiForWindow(IntPtr handle);
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct NativeRect
    {
        internal int Left;
        internal int Top;
        internal int Right;
        internal int Bottom;
    }
}

public sealed class UnverifiedUiaTitlebarScanner : ITitlebarScanner
{
    public ValueTask<TitlebarSnapshot> ScanAsync(HostWindowSnapshot host, CancellationToken cancellationToken) =>
        ValueTask.FromException<TitlebarSnapshot>(new WindowsDeviceValidationRequiredException(host.BuildIdentity));

    public void Invalidate() { }
}
#endif
