#if WINDOWS
using System.Globalization;
using System.Reflection;
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
        var stateDirectory = Path.Combine(localAppData, "CodexUsageSidebar");
        var runtimeStateStore = new RuntimeStateStore(Path.Combine(stateDirectory, "runtime-state.json"));
        var metadata = Assembly.GetExecutingAssembly().GetCustomAttributes<AssemblyMetadataAttribute>()
            .ToDictionary(attribute => attribute.Key, attribute => attribute.Value, StringComparer.Ordinal);
        var compatibilityConfiguration = CompatibilityUpdateConfiguration.Create(
            metadata.GetValueOrDefault("CompatibilityPublicKey") ?? string.Empty,
            metadata.GetValueOrDefault("CompatibilityUpdateUri") ?? string.Empty);
        var compatibilityCache = new CompatibilityPackFileCache(Path.Combine(stateDirectory, "Compatibility"));
        var compatibilityUpdater = new BackgroundCompatibilityCatalogUpdater(new CompatibilityPackUpdater(
            compatibilityConfiguration.PublicKey,
            new HttpCompatibilityPackTransport(compatibilityConfiguration.UpdateUri),
            compatibilityCache,
            () => DateTimeOffset.UtcNow));
        var compatibilityRuntime = WindowsCompatibilityRuntime.CreateAsync(
            File.ReadAllBytes(Path.Combine(AppContext.BaseDirectory, "selectors.json")),
            compatibilityConfiguration,
            compatibilityCache,
            compatibilityUpdater,
            CancellationToken.None).AsTask().GetAwaiter().GetResult();
        var safeDockPreferencesStore = new SafeDockPreferencesStore(Path.Combine(stateDirectory, "safe-dock-preferences.json"));
        SafeDockPreferences safeDockPreferences;
        try
        {
            safeDockPreferences = safeDockPreferencesStore.LoadAsync(CancellationToken.None).AsTask().GetAwaiter().GetResult();
        }
        catch (Exception)
        {
            safeDockPreferences = SafeDockPreferences.Default;
        }

        var application = new Application { ShutdownMode = ShutdownMode.OnExplicitShutdown };
        var runtime = new WindowsOverlayRuntime(
            paths,
            runtimeStateStore,
            safeDockPreferencesStore,
            safeDockPreferences,
            compatibilityRuntime.Scanner);
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
    private readonly WindowsCodexLanguageProvider languageProvider;
    private readonly RuntimeLanguageState languageState;
    private readonly WindowsTrayController tray;
    private readonly ISafeDockPreferencesStore? safeDockPreferencesStore;
    private AllowanceSnapshot? latestSnapshot;
    private TokenUsageSnapshot? latestTokenUsage;
    private AccountIdentity? latestAccount;
    private DateTimeOffset nextLanguageRefresh = DateTimeOffset.MinValue;
    private int reconcileInProgress;
    private Task? sessionTask;
    private RuntimeStateOutcome? lastOutcome;

    internal WindowsOverlayRuntime(
        WindowsRuntimePaths paths,
        IRuntimeStateStore? runtimeStateStore = null,
        ISafeDockPreferencesStore? safeDockPreferencesStore = null,
        SafeDockPreferences? safeDockPreferences = null,
        ITitlebarScanner? titlebarScanner = null)
    {
        this.safeDockPreferencesStore = safeDockPreferencesStore;
        var language = LanguageResolver.Resolve(CultureInfo.CurrentUICulture.Name);
        languageProvider = WindowsCodexLanguageProvider.CreateDefault();
        languageState = new RuntimeLanguageState(language);
        overlay = new WpfOverlaySurface(language, TimeZoneInfo.Local);
        coordinator = new WindowsHostCoordinator(
            new Win32CodexWindowLocator(),
            titlebarScanner ?? new ValidatedUiaTitlebarScanner(),
            overlay,
            runtimeStateStore: runtimeStateStore,
            safeDockPreferences: safeDockPreferences,
            safeDockPreferencesStore: safeDockPreferencesStore);
        launchPlan = AppServerLaunchPlan.Create(
            paths.CodexExecutable,
            paths.IsolatedCodexHome);
        reconcileTimer = new DispatcherTimer(
            TimeSpan.FromMilliseconds(100),
            DispatcherPriority.Background,
            async (_, _) => await ReconcileAsync(),
            Dispatcher.CurrentDispatcher);
        tray = new WindowsTrayController(
            () => lastOutcome,
            locked => _ = UpdateFallbackLockAsync(locked),
            ExportDiagnosticsAsync,
            () => Application.Current?.Shutdown());
    }

    internal void Start()
    {
        reconcileTimer.Start();
        sessionTask = RunSessionLoopAsync(cancellation.Token);
    }

    public void Dispose()
    {
        reconcileTimer.Stop();
        tray.Dispose();
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
            var state = await coordinator.ReconcileAsync(
                Volatile.Read(ref latestSnapshot),
                CurrentLanguage(),
                cancellation.Token,
                Volatile.Read(ref latestTokenUsage),
                Volatile.Read(ref latestAccount));
            lastOutcome = new RuntimeStateOutcome(
                state,
                coordinator.LastCompatibilityDecision ?? new CompatibilityDecision(
                    SemanticCompatibility.Unknown,
                    ProfileCompatibility.Unknown,
                    SafeDockPlacement.None,
                    CompatibilityFailureCode.UiaUnavailable),
                DateTimeOffset.UtcNow);
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

    private async Task UpdateFallbackLockAsync(bool locked)
    {
        var current = safeDockPreferencesStore is null
            ? SafeDockPreferences.Default
            : await safeDockPreferencesStore.LoadAsync(cancellation.Token).ConfigureAwait(false);
        var preferences = current with { FallbackLocked = locked };
        await coordinator.UpdateSafeDockPreferencesAsync(preferences, cancellation.Token).ConfigureAwait(false);
    }

    private async Task ExportDiagnosticsAsync(string destination)
    {
        var report = await new WindowsDiagnosticProbe(new Win32CodexWindowLocator())
            .CaptureAsync(includeText: false, cancellation.Token).ConfigureAwait(false);
        await WindowsDiagnosticExporter.ExportAsync(destination, report, lastOutcome, cancellation.Token).ConfigureAwait(false);
    }

    private DisplayLanguage CurrentLanguage()
    {
        var current = DateTimeOffset.Now;
        if (current < nextLanguageRefresh)
        {
            return languageState.Language;
        }
        nextLanguageRefresh = current.AddSeconds(1);
        _ = languageState.Apply(languageProvider.CurrentLanguage());
        return languageState.Language;
    }

    private async Task RunSessionLoopAsync(CancellationToken cancellationToken)
    {
        while (!cancellationToken.IsCancellationRequested)
        {
            try
            {
                var session = new AppServerSession(
                    new AppServerProcessConnectionFactory(launchPlan),
                    new AppServerProtocol("codex-usage-sidebar", QuotaDetailFormatter.ProductVersion),
                    () => DateTimeOffset.Now);
                await session.RunAsync(
                    snapshot =>
                    {
                        Volatile.Write(ref latestSnapshot, snapshot);
                        return ValueTask.CompletedTask;
                    },
                    cancellationToken,
                    usage =>
                    {
                        if (usage.Availability == TokenUsageAvailability.Available)
                        {
                            Volatile.Write(ref latestTokenUsage, usage);
                        }
                        else if (Volatile.Read(ref latestTokenUsage) is null)
                        {
                            Volatile.Write(ref latestTokenUsage, usage);
                        }
                        return ValueTask.CompletedTask;
                    },
                    account =>
                    {
                        Volatile.Write(ref latestAccount, account);
                        return ValueTask.CompletedTask;
                    });
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception)
            {
                Volatile.Write(ref latestSnapshot, null);
                Volatile.Write(ref latestTokenUsage, null);
                Volatile.Write(ref latestAccount, null);
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
