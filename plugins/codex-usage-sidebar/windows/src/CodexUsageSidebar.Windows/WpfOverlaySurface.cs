#if WINDOWS
using System.Runtime.InteropServices;
using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Threading;
using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Windows;

public sealed class WpfOverlaySurface : IOverlaySurface
{
    private const int ExtendedWindowStyle = -20;
    private const int NoActivateStyle = 0x08000000;
    private const int ToolWindowStyle = 0x00000080;
    private const int MouseActivateMessage = 0x0021;
    private const int MouseActivateNoActivate = 3;
    private readonly DisplayLanguage language;
    private readonly TimeZoneInfo timeZone;
    private readonly Window indicator;
    private readonly Window detail;
    private readonly Border indicatorSurface;
    private readonly TextBlock indicatorText;
    private readonly DispatcherTimer hoverTimer;
    private DetailInteractionState interaction = DetailInteractionState.Initial;
    private OverlayPresentation? latestPresentation;
    private QuotaDetailContent? latestContent;

    public WpfOverlaySurface(DisplayLanguage language, TimeZoneInfo timeZone)
    {
        this.language = language;
        this.timeZone = timeZone;
        indicatorText = new TextBlock
        {
            FontFamily = new FontFamily("Segoe UI"),
            FontSize = 13,
            FontWeight = FontWeights.SemiBold,
            Foreground = SystemColors.WindowTextBrush,
            TextAlignment = TextAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
            TextTrimming = TextTrimming.CharacterEllipsis,
        };
        var indicatorColor = SystemColors.WindowTextColor;
        indicatorSurface = new Border
        {
            Background = new SolidColorBrush(Color.FromArgb(
                IndicatorHitTestPolicy.BackgroundAlpha(highlighted: false),
                indicatorColor.R,
                indicatorColor.G,
                indicatorColor.B)),
            CornerRadius = new CornerRadius(10),
            Padding = new Thickness(8, 0, 8, 0),
            Child = indicatorText,
        };
        indicator = CreatePassiveWindow(indicatorSurface);
        indicator.Width = OverlayVisualMetrics.IndicatorWidth;
        detail = CreatePassiveWindow(new Border());
        detail.Width = OverlayVisualMetrics.DetailWidth;
        detail.MaxHeight = 480;
        indicator.MouseLeftButtonUp += (_, eventArgs) =>
        {
            if (eventArgs.ChangedButton != MouseButton.Left) return;
            interaction = interaction.TogglePinned(IsPointerInsideOverlay());
            RefreshInteraction();
        };
        hoverTimer = new DispatcherTimer(
            TimeSpan.FromMilliseconds(100),
            DispatcherPriority.Input,
            (_, _) => PollPointer(),
            indicator.Dispatcher);
    }

    public ValueTask ShowAsync(
        OverlayPresentation presentation,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        return OnUiAsync(() =>
        {
            latestPresentation = presentation;
            indicator.Opacity = presentation.Freshness == SnapshotFreshness.Dimmed ? 0.58 : 1;
            detail.Opacity = presentation.Freshness == SnapshotFreshness.Dimmed ? 0.58 : 1;
            latestContent = QuotaDetailFormatter.Format(
                presentation.Snapshot,
                DateTimeOffset.Now,
                language,
                timeZone);
            SetOwner(indicator, presentation.OwnerHandle);
            SetOwner(detail, presentation.OwnerHandle);
            var frame = presentation.Placement.Frame;
            UpdateIndicator(presentation.Snapshot);
            indicator.Width = frame.Width / presentation.DpiScale;
            indicator.Height = frame.Height / presentation.DpiScale;
            if (!indicator.IsVisible) new WindowInteropHelper(indicator).EnsureHandle();
            PositionPhysical(indicator, frame);
            if (!indicator.IsVisible) indicator.Show();
            hoverTimer.Start();
            RefreshInteraction();
        });
    }

    public ValueTask HideAsync(CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        return OnUiAsync(() =>
        {
            latestPresentation = null;
            latestContent = null;
            interaction = DetailInteractionState.Initial;
            hoverTimer.Stop();
            detail.Hide();
            indicator.Hide();
        });
    }

    private void PollPointer()
    {
        var inside = IsPointerInsideOverlay();
        interaction = interaction.PointerChanged(inside);
        RefreshInteraction();
    }

    private void RefreshInteraction()
    {
        var highlighted = IsPointerInside(indicator) || interaction.IsPinned;
        var color = SystemColors.WindowTextColor;
        indicatorSurface.Background = new SolidColorBrush(Color.FromArgb(
            IndicatorHitTestPolicy.BackgroundAlpha(highlighted),
            color.R,
            color.G,
            color.B));
        if (interaction.ShouldShowDetail
            && latestPresentation is not null
            && latestContent is not null)
        {
            ShowDetail(latestPresentation, latestContent);
        }
        else
        {
            detail.Hide();
        }
    }

    private bool IsPointerInsideOverlay() =>
        IsPointerInside(indicator) || IsPointerInside(detail);

    private static bool IsPointerInside(Window window)
    {
        if (!window.IsVisible || !GetCursorPos(out var cursor))
        {
            return false;
        }
        var handle = new WindowInteropHelper(window).Handle;
        if (handle == IntPtr.Zero || !GetWindowRect(handle, out var bounds))
        {
            return false;
        }
        return OverlayPointerPolicy.IsInside(
            new PointD(cursor.X, cursor.Y),
            new RectD(
                bounds.Left,
                bounds.Top,
                bounds.Right - bounds.Left,
                bounds.Bottom - bounds.Top));
    }

    private void UpdateIndicator(AllowanceSnapshot snapshot)
    {
        indicatorText.Inlines.Clear();
        var accent = WpfQuotaColors.ForRemainingPercent(snapshot.RemainingPercent);
        indicatorText.Inlines.Add(new System.Windows.Documents.Run($"{snapshot.RemainingPercent}%")
        {
            FontSize = 14,
            FontWeight = FontWeights.Bold,
            Foreground = new SolidColorBrush(accent),
        });
        var compact = QuotaDetailFormatter.FormatCompact(snapshot, language, timeZone);
        indicatorText.Inlines.Add(new System.Windows.Documents.Run(
            compact[(compact.IndexOf('·') - 1)..])
        {
            Foreground = SystemColors.WindowTextBrush,
        });
    }

    private void ShowDetail(OverlayPresentation presentation, QuotaDetailContent content)
    {
        detail.Content = BuildDetailCard(content);
        detail.SizeToContent = SizeToContent.Height;
        detail.UpdateLayout();
        var indicatorFrame = presentation.Placement.Frame;
        var workArea = WorkAreaFor(presentation.OwnerHandle);
        if (workArea is null)
        {
            detail.Hide();
            return;
        }
        var detailWidth = detail.Width * presentation.DpiScale;
        var detailHeight = detail.ActualHeight * presentation.DpiScale;
        var left = Math.Min(
            Math.Max(workArea.Value.X, indicatorFrame.Right - detailWidth),
            workArea.Value.Right - detailWidth);
        var gap = 6 * presentation.DpiScale;
        var below = indicatorFrame.Bottom + gap;
        var above = indicatorFrame.Y - detailHeight - gap;
        var top = below + detailHeight <= workArea.Value.Bottom
            ? below
            : Math.Max(workArea.Value.Y, above);
        if (!detail.IsVisible) new WindowInteropHelper(detail).EnsureHandle();
        PositionPhysical(detail, new RectD(left, top, detailWidth, detailHeight));
        if (!detail.IsVisible) detail.Show();
    }

    private static Border BuildDetailCard(QuotaDetailContent content)
    {
        var accent = WpfQuotaColors.ForRemainingPercent(content.RemainingPercent);
        var body = new StackPanel();
        var header = new Grid { Margin = new Thickness(14, 11, 14, 9) };
        header.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        header.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        header.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        header.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        var title = new TextBlock
        {
            Text = content.Title,
            FontFamily = new FontFamily("Segoe UI"),
            FontSize = OverlayVisualMetrics.HeaderTitleFontSize,
            FontWeight = FontWeights.SemiBold,
            MaxWidth = OverlayVisualMetrics.HeaderTitleMaximumWidth,
            VerticalAlignment = VerticalAlignment.Center,
            TextTrimming = TextTrimming.CharacterEllipsis,
        };
        Grid.SetColumn(title, 0);
        header.Children.Add(title);
        var highlight = SystemColors.HighlightColor;
        var badge = new Border
        {
            BorderBrush = new SolidColorBrush(Color.FromArgb(
                133,
                highlight.R,
                highlight.G,
                highlight.B)),
            BorderThickness = new Thickness(0.75),
            CornerRadius = new CornerRadius(7),
            Margin = new Thickness(6, 0, 8, 0),
            Padding = new Thickness(5, 0, 5, 0),
            Height = OverlayVisualMetrics.VersionBadgeHeight,
            VerticalAlignment = VerticalAlignment.Center,
            Child = new TextBlock
            {
                Text = "v0.3.0-beta.1",
                FontFamily = new FontFamily("Segoe UI"),
                FontSize = OverlayVisualMetrics.VersionBadgeFontSize,
                FontWeight = FontWeights.Medium,
                Foreground = SystemColors.HighlightBrush,
                TextWrapping = TextWrapping.NoWrap,
                VerticalAlignment = VerticalAlignment.Center,
            },
        };
        Grid.SetColumn(badge, 1);
        header.Children.Add(badge);
        var remaining = new TextBlock
        {
            Text = $"{content.RemainingPercent}%",
            FontFamily = new FontFamily("Segoe UI"),
            FontSize = OverlayVisualMetrics.RemainingPercentFontSize,
            FontWeight = FontWeights.SemiBold,
            Foreground = new SolidColorBrush(accent),
        };
        Grid.SetColumn(remaining, 3);
        header.Children.Add(remaining);
        body.Children.Add(header);

        body.Children.Add(new WpfQuotaProgressBar
        {
            Height = OverlayVisualMetrics.ProgressTrackHeight,
            Margin = new Thickness(12, 0, 12, 11),
            RemainingPercent = content.RemainingPercent,
        });
        body.Children.Add(new Border
        {
            Height = 1,
            Background = SystemColors.ActiveBorderBrush,
            Opacity = 0.55,
        });

        var rows = new StackPanel { Margin = new Thickness(12, 7, 12, 8) };
        foreach (var row in content.Rows)
        {
            var grid = new Grid { Margin = new Thickness(0, 3, 0, 3) };
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(108) });
            grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            var label = new TextBlock
            {
                Text = row.Label,
                FontFamily = new FontFamily("Segoe UI"),
                FontSize = 12,
                Foreground = SystemColors.GrayTextBrush,
                TextWrapping = TextWrapping.Wrap,
            };
            grid.Children.Add(label);
            var value = BuildDetailValue(row.Value, accent);
            Grid.SetColumn(value, 1);
            grid.Children.Add(value);
            rows.Children.Add(grid);
        }
        body.Children.Add(new ScrollViewer
        {
            Content = rows,
            VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
            HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled,
            MaxHeight = 390,
        });
        return new Border
        {
            Width = OverlayVisualMetrics.DetailWidth,
            Background = SystemColors.WindowBrush,
            BorderBrush = SystemColors.ActiveBorderBrush,
            BorderThickness = new Thickness(0.5),
            CornerRadius = new CornerRadius(12),
            Child = body,
        };
    }

    private static TextBlock BuildDetailValue(string value, Color accent)
    {
        var text = new TextBlock
        {
            FontFamily = new FontFamily("Segoe UI"),
            FontSize = OverlayVisualMetrics.DetailValueFontSize,
            TextAlignment = TextAlignment.Right,
            TextWrapping = TextWrapping.Wrap,
        };
        foreach (var segment in QuotaCountdownSegmenter.Segments(value))
        {
            var run = new System.Windows.Documents.Run(segment.Text)
            {
                BaselineAlignment = BaselineAlignment.Baseline,
            };
            switch (segment.Role)
            {
                case QuotaCountdownSegmentRole.Digits:
                    run.FontSize = OverlayVisualMetrics.CountdownDigitFontSize;
                    run.FontWeight = FontWeights.SemiBold;
                    run.Foreground = new SolidColorBrush(accent);
                    break;
                case QuotaCountdownSegmentRole.Unit:
                    run.FontSize = OverlayVisualMetrics.CountdownUnitFontSize;
                    run.FontWeight = FontWeights.Medium;
                    run.Foreground = SystemColors.GrayTextBrush;
                    break;
                case QuotaCountdownSegmentRole.Punctuation:
                case QuotaCountdownSegmentRole.Suffix:
                    run.FontSize = OverlayVisualMetrics.CountdownUnitFontSize;
                    run.FontWeight = FontWeights.Normal;
                    run.Foreground = SystemColors.GrayTextBrush;
                    break;
                default:
                    run.FontSize = OverlayVisualMetrics.DetailValueFontSize;
                    run.FontWeight = FontWeights.Normal;
                    run.Foreground = SystemColors.WindowTextBrush;
                    break;
            }
            text.Inlines.Add(run);
        }
        return text;
    }

    private static Window CreatePassiveWindow(UIElement content)
    {
        var window = new Window
        {
            AllowsTransparency = true,
            Background = Brushes.Transparent,
            WindowStyle = WindowStyle.None,
            ResizeMode = ResizeMode.NoResize,
            ShowActivated = false,
            ShowInTaskbar = false,
            Focusable = false,
            UseLayoutRounding = true,
            SnapsToDevicePixels = true,
            Content = content,
        };
        window.SourceInitialized += (_, _) =>
        {
            var handle = new WindowInteropHelper(window).Handle;
            var style = GetWindowLongPtr(handle, ExtendedWindowStyle).ToInt64();
            SetWindowLongPtr(handle, ExtendedWindowStyle, new IntPtr(style | NoActivateStyle | ToolWindowStyle));
            HwndSource.FromHwnd(handle)?.AddHook(NoActivateWindowHook);
        };
        return window;
    }

    private static IntPtr NoActivateWindowHook(
        IntPtr window,
        int message,
        IntPtr wordParameter,
        IntPtr longParameter,
        ref bool handled)
    {
        if (message != MouseActivateMessage) return IntPtr.Zero;
        handled = true;
        return new IntPtr(MouseActivateNoActivate);
    }

    private static void PositionPhysical(Window window, RectD frame)
    {
        var handle = new WindowInteropHelper(window).Handle;
        if (handle == IntPtr.Zero) return;
        if (!SetWindowPos(
            handle,
            IntPtr.Zero,
            checked((int)Math.Round(frame.X)),
            checked((int)Math.Round(frame.Y)),
            checked((int)Math.Round(frame.Width)),
            checked((int)Math.Round(frame.Height)),
            OverlayWindowPolicy.PositionFlags))
        {
            throw new Win32Exception(Marshal.GetLastWin32Error(), "Unable to position the overlay window.");
        }
    }

    private static void SetOwner(Window window, IntPtr owner)
    {
        var helper = new WindowInteropHelper(window);
        if (helper.Owner != owner) helper.Owner = owner;
    }

    private ValueTask OnUiAsync(Action action)
    {
        if (indicator.Dispatcher.CheckAccess())
        {
            action();
            return ValueTask.CompletedTask;
        }
        return new ValueTask(indicator.Dispatcher.InvokeAsync(action).Task);
    }

    private static RectD? WorkAreaFor(IntPtr owner)
    {
        var monitor = MonitorFromWindow(owner, 2);
        var info = new MonitorInfo { Size = Marshal.SizeOf<MonitorInfo>() };
        if (monitor == IntPtr.Zero || !GetMonitorInfo(monitor, ref info))
        {
            return null;
        }
        return new RectD(
            info.Work.Left,
            info.Work.Top,
            info.Work.Right - info.Work.Left,
            info.Work.Bottom - info.Work.Top);
    }

    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW")]
    private static extern IntPtr GetWindowLongPtr(IntPtr window, int index);

    [DllImport("user32.dll", EntryPoint = "SetWindowLongPtrW")]
    private static extern IntPtr SetWindowLongPtr(IntPtr window, int index, IntPtr value);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool SetWindowPos(
        IntPtr window,
        IntPtr insertAfter,
        int x,
        int y,
        int width,
        int height,
        uint flags);

    [DllImport("user32.dll")]
    private static extern IntPtr MonitorFromWindow(IntPtr window, uint flags);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetMonitorInfo(IntPtr monitor, ref MonitorInfo info);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetCursorPos(out NativePoint point);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool GetWindowRect(IntPtr window, out NativeRect rectangle);

    [StructLayout(LayoutKind.Sequential)]
    private struct NativePoint
    {
        internal int X;
        internal int Y;
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
#endif
