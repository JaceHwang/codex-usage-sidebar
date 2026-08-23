#if WINDOWS
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows.Automation;
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
                var dpiScale = Math.Max(1, NativeMethods.GetDpiForWindow(handle)) / 96d;
                var bounds = WindowsCoordinateSpace.ToPhysicalBounds(
                    rectangle.Left,
                    rectangle.Top,
                    rectangle.Right,
                    rectangle.Bottom,
                    dpiScale);
                if (bounds.Width < 400 * dpiScale || bounds.Height < 300 * dpiScale)
                {
                    return true;
                }
                var version = versionInfo?.FileVersion ?? "unknown";
                var workArea = WorkAreaFor(handle);
                var captionBounds = CaptionBoundsFor(handle, bounds, dpiScale);
                candidates.Add((new HostWindowSnapshot(
                    handle,
                    bounds,
                    handle == foreground,
                    dpiScale,
                    version,
                    WorkArea: workArea,
                    CaptionBounds: captionBounds),
                    bounds.Width * bounds.Height));
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

    private static RectD? WorkAreaFor(IntPtr handle)
    {
        var monitor = NativeMethods.MonitorFromWindow(handle, 2);
        var info = new MonitorInfo { Size = Marshal.SizeOf<MonitorInfo>() };
        if (monitor == IntPtr.Zero || !NativeMethods.GetMonitorInfo(monitor, ref info)) return null;
        return new RectD(
            info.Work.Left,
            info.Work.Top,
            info.Work.Right - info.Work.Left,
            info.Work.Bottom - info.Work.Top);
    }

    private static RectD? CaptionBoundsFor(IntPtr handle, RectD hostBounds, double dpiScale)
    {
        try
        {
            var root = AutomationElement.FromHandle(handle);
            if (root is null) return null;
            var condition = new AndCondition(
                new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Pane),
                new PropertyCondition(AutomationElement.ClassNameProperty, "ChromeNodeCaptionButtonContainer"));
            var candidates = root.FindAll(TreeScope.Descendants, condition)
                .Cast<AutomationElement>()
                .Select(element => new HostWindowGeometry.CaptionBoundsCandidate(
                    BoundsFor(element),
                    HasVerifiedCaptionButtons(element)))
                .ToArray();
            return HostWindowGeometry.TryResolveVerifiedCaptionBounds(hostBounds, candidates, dpiScale);
        }
        catch (ElementNotAvailableException)
        {
            return null;
        }
        catch (InvalidOperationException)
        {
            return null;
        }
    }

    private static RectD BoundsFor(AutomationElement element)
    {
        var bounds = element.Current.BoundingRectangle;
        return new RectD(bounds.X, bounds.Y, bounds.Width, bounds.Height);
    }

    private static bool HasVerifiedCaptionButtons(AutomationElement container)
    {
        foreach (var automationId in new[] { "view_1", "view_2", "view_3", "view_4" })
        {
            var condition = new AndCondition(
                new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button),
                new PropertyCondition(AutomationElement.AutomationIdProperty, automationId),
                new PropertyCondition(AutomationElement.ClassNameProperty, "ChromeNodeCaptionButton"));
            if (container.FindAll(TreeScope.Descendants, condition).Count != 1) return false;
        }
        return true;
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

        [DllImport("user32.dll")]
        internal static extern IntPtr MonitorFromWindow(IntPtr window, uint flags);

        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool GetMonitorInfo(IntPtr monitor, ref MonitorInfo info);
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct NativeRect
    {
        internal int Left;
        internal int Top;
        internal int Right;
        internal int Bottom;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    private struct MonitorInfo
    {
        internal int Size;
        internal NativeRect Monitor;
        internal NativeRect Work;
        internal uint Flags;
    }
}

public sealed class UnverifiedUiaTitlebarScanner : ITitlebarScanner
{
    public ValueTask<TitlebarSnapshot> ScanAsync(HostWindowSnapshot host, CancellationToken cancellationToken) =>
        ValueTask.FromException<TitlebarSnapshot>(new WindowsDeviceValidationRequiredException(host.BuildIdentity));

    public void Invalidate() { }
}
#endif
