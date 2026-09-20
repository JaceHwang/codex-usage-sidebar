#if WINDOWS
using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows.Interop;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Media;
using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Windows;

public sealed partial class WpfOverlaySurface
{
    private ContextMenu? settingsMenu;
    private OutsideClickMonitor? outsideClickMonitor;
    public event Action? ReloadRequested;
    public event Action? QuitRequested;

    private void DismissDetail()
    {
        if (settingsMenu is not null) settingsMenu.IsOpen = false;
        interaction = new DetailInteractionState(false, IsPointerInside(indicator), true, false);
        detail.Hide();
        UpdateOutsideClickMonitor();
    }

    private void UpdateOutsideClickMonitor()
    {
        if (!detail.IsVisible || !interaction.IsPinned)
        {
            outsideClickMonitor?.Dispose();
            outsideClickMonitor = null;
            return;
        }
        if (outsideClickMonitor is not null) return;
        try
        {
            outsideClickMonitor = new OutsideClickMonitor(indicator.Dispatcher, point =>
            {
                var inside = ContainsScreenPoint(indicator, point) || ContainsScreenPoint(detail, point);
                var insideMenu = false;
                if (settingsMenu?.IsOpen == true)
                {
                    var window = WindowFromPoint(new NativePoint { X = (int)point.X, Y = (int)point.Y });
                    _ = GetWindowThreadProcessId(window, out var processId);
                    insideMenu = processId == (uint)Environment.ProcessId;
                }
                interaction = interaction.PointerPressed(inside, insideMenu);
                if (!interaction.ShouldShowDetail) DismissDetail();
            });
        }
        catch (Win32Exception error)
        {
            Trace.TraceWarning("Outside-click monitor unavailable: {0}", error.NativeErrorCode);
        }
    }

    private static bool ContainsScreenPoint(Window window, PointD point)
    {
        if (!window.IsVisible || !GetWindowRect(new WindowInteropHelper(window).Handle, out var frame)) return false;
        return OverlayPointerPolicy.IsInside(point, new Core.RectD(frame.Left, frame.Top,
            frame.Right - frame.Left, frame.Bottom - frame.Top));
    }

    [DllImport("user32.dll")]
    private static extern IntPtr WindowFromPoint(NativePoint point);
    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);

    private void ShowSettings(FrameworkElement target)
    {
        if (latestPresentation is null) return;
        if (settingsMenu?.IsOpen == true)
        {
            settingsMenu.IsOpen = false;
            return;
        }
        // Keep the quota card and its footer anchor stable while using either menu level.
        interaction = new DetailInteractionState(true, true, false, false);
        var menu = CreateMenu(target, 176);
        foreach (var descriptor in QuotaSettingsMenu.Create(latestPresentation.Language, placementPreferences.Mode))
        {
            var item = MenuRow(descriptor.Label, descriptor.Icon, 176);
            if (descriptor.Children is { } choices)
            {
                foreach (var choice in choices)
                {
                    var child = MenuRow(choice.Label, choice.Icon, 156, choice.Selected);
                    child.Click += async (_, _) =>
                    {
                        menu.IsOpen = false;
                        await SetPlacementModeAsync(choice.Mode);
                    };
                    item.Items.Add(child);
                }
            }
            else
            {
                item.Click += (_, _) =>
                {
                    DismissDetail();
                    switch (descriptor.Action)
                    {
                        case QuotaSettingsAction.CheckUpdates:
                            try { Process.Start(new ProcessStartInfo("https://github.com/JaceHwang/codex-usage-sidebar/releases") { UseShellExecute = true }); }
                            catch (Exception error) when (error is Win32Exception or InvalidOperationException)
                            { Trace.TraceWarning("Unable to open releases: {0}", error.GetType().Name); }
                            break;
                        case QuotaSettingsAction.Reload: ReloadRequested?.Invoke(); break;
                        case QuotaSettingsAction.Quit: QuitRequested?.Invoke(); break;
                    }
                };
            }
            menu.Items.Add(item);
        }
        settingsMenu = menu;
        menu.IsOpen = true;
        UpdateOutsideClickMonitor();
    }

    private void ShowPositionMenu(FrameworkElement target)
    {
        if (latestPresentation is null) return;
        if (settingsMenu?.IsOpen == true)
        {
            settingsMenu.IsOpen = false;
            return;
        }
        interaction = new DetailInteractionState(false, IsPointerInside(indicator), true, false);
        detail.Hide();
        var menu = CreateMenu(target, 176);
        foreach (var choice in QuotaSettingsMenu.CreatePlacementItems(
                     latestPresentation.Language,
                     placementPreferences.Mode))
        {
            var item = MenuRow(choice.Label, choice.Icon, 176, choice.Selected);
            item.Click += async (_, _) =>
            {
                menu.IsOpen = false;
                await SetPlacementModeAsync(choice.Mode);
            };
            menu.Items.Add(item);
        }
        settingsMenu = menu;
        menu.IsOpen = true;
        UpdateOutsideClickMonitor();
    }

    private ContextMenu CreateMenu(FrameworkElement target, double width) => new()
    {
        Width = width,
        FontFamily = new FontFamily("Segoe UI"),
        FontSize = 12,
        Foreground = palette.Primary,
        Background = palette.Surface,
        BorderBrush = palette.Border,
        BorderThickness = new Thickness(0.5),
        PlacementTarget = target,
        Placement = System.Windows.Controls.Primitives.PlacementMode.Custom,
        CustomPopupPlacementCallback = (popup, anchor, _) =>
        [
            new CustomPopupPlacement(new Point(anchor.Width - popup.Width, -popup.Height - 6), PopupPrimaryAxis.Horizontal),
            new CustomPopupPlacement(new Point(anchor.Width - popup.Width, anchor.Height + 6), PopupPrimaryAxis.Horizontal),
        ],
    };

    private MenuItem MenuRow(string title, string icon, double width, bool selected = false)
    {
        var header = new Grid { MinWidth = width - 72 };
        header.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        header.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(14) });
        header.Children.Add(new TextBlock { Text = title, VerticalAlignment = VerticalAlignment.Center });
        if (selected)
        {
            var check = new TextBlock { Text = "✓", HorizontalAlignment = HorizontalAlignment.Right };
            Grid.SetColumn(check, 1);
            header.Children.Add(check);
        }
        var item = new MenuItem
        {
            Header = header,
            Icon = new TextBlock { Text = icon, FontFamily = new FontFamily("Segoe MDL2 Assets"), FontSize = 14,
                Foreground = palette.Secondary, VerticalAlignment = VerticalAlignment.Center },
            Height = 32,
            Width = width,
            Foreground = palette.Primary,
            Background = palette.Surface,
        };
        System.Windows.Automation.AutomationProperties.SetName(item, title);
        return item;
    }
}
#endif
