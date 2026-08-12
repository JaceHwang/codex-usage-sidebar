#if WINDOWS
using System.Globalization;
using System.ComponentModel;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Automation;
using System.Windows.Controls;
using System.Windows.Media;

namespace CodexUsageSidebar.Installer;

public static class InstallerApplication
{
    [STAThread]
    public static int Main(string[] args)
    {
        var architecture = RuntimeInformation.OSArchitecture == Architecture.X64
            ? "x64"
            : RuntimeInformation.OSArchitecture.ToString().ToLowerInvariant();
        var metadata = Assembly.GetExecutingAssembly()
            .GetCustomAttributes<AssemblyMetadataAttribute>()
            .ToDictionary(attribute => attribute.Key, attribute => attribute.Value, StringComparer.Ordinal);
        try
        {
            var deviceInstall = DevicePayloadInstallCommand.TryCreate(
                args,
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                architecture,
                Environment.OSVersion.Version.Build,
                metadata.GetValueOrDefault("DeviceSourceCommit"),
                metadata.GetValueOrDefault("DevicePayloadManifestSha256"));
            if (deviceInstall is not null)
            {
                deviceInstall.Install();
                return 0;
            }
        }
        catch (Exception)
        {
            return 70;
        }

        InstallerUiMode mode;
        try
        {
            mode = InstallerUiModeParser.Parse(args);
        }
        catch (ArgumentException error)
        {
            MessageBox.Show(error.Message, "Codex Usage Sidebar", MessageBoxButton.OK, MessageBoxImage.Error);
            return 64;
        }

        var controller = new InstallerUiController(
            CultureInfo.CurrentUICulture.Name,
            mode,
            DeviceTestInstallerRuntimeFactory.TryCreate(
                AppContext.BaseDirectory,
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                architecture,
                Environment.OSVersion.Version.Build,
                metadata.GetValueOrDefault("DeviceSourceCommit"),
                metadata.GetValueOrDefault("DevicePayloadManifestSha256"))
            ?? new UnavailableInstallerUiActions());
        var application = new Application { ShutdownMode = ShutdownMode.OnMainWindowClose };
        return application.Run(new InstallerWindow(controller));
    }

    private sealed class UnavailableInstallerUiActions : IInstallerUiActions
    {
        public Task ExecuteAsync(InstallerUiMode mode, CancellationToken cancellationToken) =>
            Task.FromException(new InvalidOperationException(
                "This development shell has no real-device-validated setup payload."));
    }
}

public sealed class InstallerWindow : Window
{
    private readonly InstallerUiController controller;
    private readonly TextBlock title = new();
    private readonly TextBlock description = new();
    private readonly TextBlock status = new();
    private readonly Button primary = new();
    private readonly Button cancel = new();
    private readonly CancellationTokenSource operationCancellation = new();

    public InstallerWindow(InstallerUiController controller)
    {
        this.controller = controller;
        Width = 560;
        Height = 340;
        MinWidth = 560;
        MinHeight = 340;
        ResizeMode = ResizeMode.NoResize;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;
        FontFamily = new FontFamily("Segoe UI");
        Background = SystemColors.WindowBrush;
        Foreground = SystemColors.WindowTextBrush;
        UseLayoutRounding = true;
        SnapsToDevicePixels = true;

        var root = new Grid { Margin = new Thickness(32, 28, 32, 24) };
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        root.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        root.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

        var heading = new StackPanel { Orientation = Orientation.Horizontal };
        title.FontSize = 24;
        title.FontWeight = FontWeights.SemiBold;
        title.VerticalAlignment = VerticalAlignment.Center;
        heading.Children.Add(title);
        var badge = new Border
        {
            BorderBrush = SystemColors.HighlightBrush,
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(5),
            Margin = new Thickness(12, 2, 0, 0),
            Padding = new Thickness(7, 2, 7, 2),
            VerticalAlignment = VerticalAlignment.Center,
            Child = new TextBlock
            {
                Text = "0.3.0-beta.1",
                Foreground = SystemColors.HighlightBrush,
                FontSize = 11,
                FontWeight = FontWeights.SemiBold,
            },
        };
        heading.Children.Add(badge);
        Grid.SetRow(heading, 0);
        root.Children.Add(heading);

        description.Margin = new Thickness(0, 18, 0, 0);
        description.FontSize = 14;
        description.TextWrapping = TextWrapping.Wrap;
        Grid.SetRow(description, 1);
        root.Children.Add(description);

        status.Margin = new Thickness(0, 22, 0, 0);
        status.FontSize = 13;
        status.TextWrapping = TextWrapping.Wrap;
        status.VerticalAlignment = VerticalAlignment.Top;
        AutomationProperties.SetLiveSetting(status, AutomationLiveSetting.Polite);
        Grid.SetRow(status, 2);
        root.Children.Add(status);

        var buttons = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Right,
        };
        cancel.MinWidth = 96;
        cancel.Padding = new Thickness(16, 7, 16, 7);
        cancel.Margin = new Thickness(0, 0, 10, 0);
        cancel.IsCancel = true;
        cancel.Click += (_, _) => Close();
        buttons.Children.Add(cancel);
        primary.MinWidth = 112;
        primary.Padding = new Thickness(18, 7, 18, 7);
        primary.IsDefault = true;
        primary.Click += async (_, _) =>
            await controller.ExecuteAsync(operationCancellation.Token);
        buttons.Children.Add(primary);
        Grid.SetRow(buttons, 3);
        root.Children.Add(buttons);

        Content = root;
        controller.Changed += OnControllerChanged;
        Closing += PreventUnsafeClose;
        Closed += (_, _) =>
        {
            controller.Changed -= OnControllerChanged;
            operationCancellation.Dispose();
        };
        Apply(controller.Model);
    }

    private void PreventUnsafeClose(object? sender, CancelEventArgs eventArgs)
    {
        if (controller.Model.State == InstallerUiState.Working)
        {
            eventArgs.Cancel = true;
        }
    }

    private void OnControllerChanged(object? sender, InstallerUiModel model)
    {
        if (!Dispatcher.CheckAccess())
        {
            Dispatcher.Invoke(() => Apply(model));
            return;
        }
        Apply(model);
    }

    private void Apply(InstallerUiModel model)
    {
        Title = model.Title;
        title.Text = model.Title;
        description.Text = model.Description;
        status.Text = model.Status;
        primary.Content = model.PrimaryAction;
        primary.IsEnabled = model.CanExecute;
        cancel.Content = model.CancelAction;
        cancel.IsEnabled = model.CanCancel;
        AutomationProperties.SetName(primary, model.PrimaryAction);
        AutomationProperties.SetName(cancel, cancel.Content?.ToString() ?? model.CancelAction);
    }

}
#endif
