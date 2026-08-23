#if WINDOWS
using System.Drawing;
using System.Windows.Forms;
#endif

namespace CodexUsageSidebar.Windows;

public enum WindowsTrayAction { ShowStatus, LockSafeDock, UnlockSafeDock, ExportDiagnostics, Exit }

public static class WindowsTrayActions
{
    public static IReadOnlyList<WindowsTrayAction> For(RuntimeStateOutcome? state) =>
    [
        WindowsTrayAction.ShowStatus,
        state?.Decision.Profile == ProfileCompatibility.FallbackLocked ? WindowsTrayAction.UnlockSafeDock : WindowsTrayAction.LockSafeDock,
        WindowsTrayAction.ExportDiagnostics,
        WindowsTrayAction.Exit,
    ];
}

#if WINDOWS
public sealed class WindowsTrayController : IDisposable
{
    private readonly NotifyIcon icon;
    private readonly Func<RuntimeStateOutcome?> state;
    private readonly Action<bool> setFallbackLock;
    private readonly Func<string, Task> exportDiagnostics;
    private readonly Action exit;

    public WindowsTrayController(
        Func<RuntimeStateOutcome?> state,
        Action<bool> setFallbackLock,
        Func<string, Task> exportDiagnostics,
        Action exit)
    {
        this.state = state;
        this.setFallbackLock = setFallbackLock;
        this.exportDiagnostics = exportDiagnostics;
        this.exit = exit;
        icon = new NotifyIcon { Icon = SystemIcons.Information, Visible = true, Text = "Codex Usage Sidebar" };
        icon.ContextMenuStrip = new ContextMenuStrip();
        icon.ContextMenuStrip.Opening += (_, _) => Populate();
        icon.DoubleClick += (_, _) => ShowStatus();
    }

    public void Dispose()
    {
        icon.Visible = false;
        icon.Dispose();
    }

    private void Populate()
    {
        var menu = icon.ContextMenuStrip!;
        menu.Items.Clear();
        foreach (var action in WindowsTrayActions.For(state()))
        {
            var item = new ToolStripMenuItem(action switch
            {
                WindowsTrayAction.ShowStatus => "Status",
                WindowsTrayAction.LockSafeDock => "Lock safe dock",
                WindowsTrayAction.UnlockSafeDock => "Unlock safe dock",
                WindowsTrayAction.ExportDiagnostics => "Export diagnostics…",
                _ => "Exit",
            });
            item.Click += async (_, _) => await ExecuteAsync(action).ConfigureAwait(false);
            menu.Items.Add(item);
        }
    }

    private Task ExecuteAsync(WindowsTrayAction action)
    {
        switch (action)
        {
            case WindowsTrayAction.ShowStatus: ShowStatus(); break;
            case WindowsTrayAction.LockSafeDock: setFallbackLock(true); break;
            case WindowsTrayAction.UnlockSafeDock: setFallbackLock(false); break;
            case WindowsTrayAction.ExportDiagnostics: ExportDiagnostics(); break;
            case WindowsTrayAction.Exit: exit(); break;
        }
        return Task.CompletedTask;
    }

    private void ShowStatus()
    {
        icon.ShowBalloonTip(3000, "Codex Usage Sidebar", WindowsControlCommands.Status(state(), true), ToolTipIcon.Info);
    }

    private void ExportDiagnostics()
    {
        using var dialog = new SaveFileDialog { Filter = "Diagnostic archive (*.zip)|*.zip", DefaultExt = "zip", AddExtension = true };
        if (dialog.ShowDialog() == DialogResult.OK) _ = exportDiagnostics(dialog.FileName);
    }
}
#endif
