#if WINDOWS
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Windows.Threading;

namespace CodexUsageSidebar.Windows;

/// Passive, short-lived monitor for dismissing a pinned card. No input is
/// intercepted, persisted or transmitted. UI work is deferred out of the hook.
internal sealed class OutsideClickMonitor : IDisposable
{
    private readonly HookProcedure procedure;
    private IntPtr hook;

    internal OutsideClickMonitor(Dispatcher dispatcher, Action<PointD> pressed)
    {
        procedure = (code, message, data) =>
        {
            if (code >= 0 && message.ToInt64() is 0x0201 or 0x0204 or 0x0207 or 0x020B)
            {
                var point = Marshal.PtrToStructure<NativePoint>(data);
                if (!dispatcher.HasShutdownStarted)
                    dispatcher.BeginInvoke(DispatcherPriority.Input, new Action(() =>
                    {
                        if (hook != IntPtr.Zero) pressed(new PointD(point.X, point.Y));
                    }));
            }
            return CallNextHookEx(IntPtr.Zero, code, message, data);
        };
        hook = SetWindowsHookEx(14, procedure, GetModuleHandle(null), 0);
        if (hook == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
    }

    public void Dispose()
    {
        if (hook == IntPtr.Zero) return;
        _ = UnhookWindowsHookEx(hook);
        hook = IntPtr.Zero;
    }

    private delegate IntPtr HookProcedure(int code, IntPtr message, IntPtr data);
    [StructLayout(LayoutKind.Sequential)]
    private struct NativePoint { public int X; public int Y; }
    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr SetWindowsHookEx(int id, HookProcedure procedure, IntPtr module, uint thread);
    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool UnhookWindowsHookEx(IntPtr hook);
    [DllImport("user32.dll")]
    private static extern IntPtr CallNextHookEx(IntPtr hook, int code, IntPtr message, IntPtr data);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    private static extern IntPtr GetModuleHandle(string? name);
}
#endif
