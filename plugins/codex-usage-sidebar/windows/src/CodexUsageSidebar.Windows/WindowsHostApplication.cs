#if WINDOWS
using System.Globalization;
using System.Security.Principal;
using System.Windows;
using System.Windows.Threading;
using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Windows;

public static class WindowsHostApplication
{
    [STAThread]
    public static int Main(string[] args)
    {
        if (WindowsHostArguments.TryParse(args) is null) return 64;
        var userIdentity = WindowsIdentity.GetCurrent().User?.Value;
        if (string.IsNullOrWhiteSpace(userIdentity)) return 70;
        using var singleton = PerUserHostSingleton.TryAcquire(userIdentity);
        if (singleton is null) return 0;
        var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        var paths = WindowsRuntimePaths.Create(AppContext.BaseDirectory, localAppData);
        if (!File.Exists(paths.CodexExecutable))
        {
            return 70;
        }
        Directory.CreateDirectory(paths.IsolatedCodexHome);

        var application = new Application { ShutdownMode = ShutdownMode.OnExplicitShutdown };
        var runtime = new WindowsOverlayRuntime(paths);
        application.Exit += (_, _) => runtime.Dispose();
        runtime.Start();
        return application.Run();
    }
}

internal sealed class WindowsOverlayRuntime : IDisposable
{
    private readonly CancellationTokenSource cancellation = new();
    private readonly WindowsHostCoordinator coordinator;
    private readonly IOverlaySurface overlay;
    private readonly AppServerLaunchPlan launchPlan;
    private readonly DispatcherTimer reconcileTimer;
    private AllowanceSnapshot? latestSnapshot;
    private int reconcileInProgress;
    private Task? sessionTask;

    internal WindowsOverlayRuntime(WindowsRuntimePaths paths)
    {
        var language = LanguageResolver.Resolve(CultureInfo.CurrentUICulture.Name);
        overlay = new WpfOverlaySurface(language, TimeZoneInfo.Local);
        coordinator = new WindowsHostCoordinator(
            new Win32CodexWindowLocator(),
            new ValidatedUiaTitlebarScanner(),
            overlay);
        launchPlan = AppServerLaunchPlan.Create(
            paths.CodexExecutable,
            paths.IsolatedCodexHome);
        reconcileTimer = new DispatcherTimer(
            TimeSpan.FromMilliseconds(100),
            DispatcherPriority.Background,
            async (_, _) => await ReconcileAsync(),
            Dispatcher.CurrentDispatcher);
    }

    internal void Start()
    {
        reconcileTimer.Start();
        sessionTask = RunSessionLoopAsync(cancellation.Token);
    }

    public void Dispose()
    {
        reconcileTimer.Stop();
        cancellation.Cancel();
        cancellation.Dispose();
    }

    private async Task ReconcileAsync()
    {
        if (Interlocked.Exchange(ref reconcileInProgress, 1) != 0)
        {
            return;
        }
        try
        {
            await coordinator.ReconcileAsync(
                Volatile.Read(ref latestSnapshot),
                cancellation.Token);
        }
        catch (OperationCanceledException) when (cancellation.IsCancellationRequested)
        {
        }
        catch (Exception)
        {
            try
            {
                await overlay.HideAsync(CancellationToken.None);
            }
            catch (Exception)
            {
                // A reconciliation failure must never terminate the WPF
                // dispatcher. The next tick retries from a fail-hidden state.
            }
        }
        finally
        {
            Volatile.Write(ref reconcileInProgress, 0);
        }
    }

    private async Task RunSessionLoopAsync(CancellationToken cancellationToken)
    {
        while (!cancellationToken.IsCancellationRequested)
        {
            try
            {
                var session = new AppServerSession(
                    new AppServerProcessConnectionFactory(launchPlan),
                    new AppServerProtocol("codex-usage-sidebar", "0.3.0"),
                    () => DateTimeOffset.Now);
                await session.RunAsync(snapshot =>
                {
                    Volatile.Write(ref latestSnapshot, snapshot);
                    return ValueTask.CompletedTask;
                }, cancellationToken);
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception)
            {
                Volatile.Write(ref latestSnapshot, null);
                try
                {
                    await Task.Delay(TimeSpan.FromSeconds(5), cancellationToken);
                }
                catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
                {
                    break;
                }
            }
        }
    }
}
#endif
