#if WINDOWS
using System.Windows.Automation;
using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Windows;

public sealed class ValidatedUiaTitlebarScanner : ITitlebarScanner
{
    private const int MaximumNodes = UiaTraversalBudget.ProductionMaximumNodes;
    private const int MaximumDepth = UiaTraversalBudget.ProductionMaximumDepth;
    private static readonly TimeSpan ScanTimeout = TimeSpan.FromSeconds(2);
    private readonly ValidatedTitlebarCache cache = new();
    private readonly object scanGate = new();
    private InFlightScan? inFlight;

    public TitlebarSnapshot? TryGetCurrent(HostWindowSnapshot host) => cache.TryGet(host);
    public TitlebarSnapshot? TryGetRetained(HostWindowSnapshot host) => cache.TryGetRetained(host);

    public async ValueTask<TitlebarSnapshot> ScanAsync(
        HostWindowSnapshot host,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        Task<TitlebarSnapshot> scanTask;
        var identity = ScanIdentity.For(host);
        lock (scanGate)
        {
            if (inFlight is null || inFlight.Task.IsCompleted)
            {
                inFlight?.Cancellation.Dispose();
                var workerCancellation = new CancellationTokenSource(ScanTimeout);
                inFlight = new InFlightScan(
                    identity,
                    Task.Run(
                        () => Scan(host, workerCancellation.Token),
                        CancellationToken.None),
                    workerCancellation);
            }
            if (inFlight.Identity != identity)
            {
                throw new WindowsDeviceValidationRequiredException(host.BuildIdentity);
            }
            scanTask = inFlight.Task;
        }

        using var scanCancellation = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        scanCancellation.CancelAfter(ScanTimeout);
        try
        {
            var snapshot = await scanTask.WaitAsync(scanCancellation.Token).ConfigureAwait(false);
            cache.Store(host, snapshot);
            return snapshot;
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            throw new WindowsDeviceValidationRequiredException(host.BuildIdentity);
        }
    }

    private sealed record InFlightScan(
        ScanIdentity Identity,
        Task<TitlebarSnapshot> Task,
        CancellationTokenSource Cancellation);

    private readonly record struct ScanIdentity(
        IntPtr Handle,
        RectD Bounds,
        double DpiScale,
        string BuildIdentity)
    {
        internal static ScanIdentity For(HostWindowSnapshot host) => new(
            host.Handle, host.Bounds, host.DpiScale, host.BuildIdentity);
    }

    public void Invalidate() => cache.Invalidate();

    private static TitlebarSnapshot Scan(
        HostWindowSnapshot host,
        CancellationToken cancellationToken)
    {
        var root = AutomationElement.FromHandle(host.Handle);
        if (root is null)
        {
            throw new WindowsDeviceValidationRequiredException(host.BuildIdentity);
        }

        var nodes = new List<UiaStructureNode>();
        Append(root, 0, nodes, cancellationToken);
        var snapshot = CodexTitlebarSelector.TryResolve(
            host.BuildIdentity,
            host.DpiScale,
            host.Bounds,
            nodes);
        return snapshot ?? throw new WindowsDeviceValidationRequiredException(host.BuildIdentity);
    }

    private static void Append(
        AutomationElement element,
        int depth,
        List<UiaStructureNode> nodes,
        CancellationToken cancellationToken)
    {
        if (depth > MaximumDepth || nodes.Count >= MaximumNodes)
        {
            return;
        }
        cancellationToken.ThrowIfCancellationRequested();
        try
        {
            var current = element.Current;
            var bounds = current.BoundingRectangle;
            var name = current.Name ?? string.Empty;
            var nodeBounds = new RectD(bounds.X, bounds.Y, bounds.Width, bounds.Height);
            if (UiaTraversalBudget.HasFiniteBounds(nodeBounds))
            {
                nodes.Add(new UiaStructureNode(
                    depth,
                    current.ControlType?.ProgrammaticName ?? string.Empty,
                    current.AutomationId ?? string.Empty,
                    current.ClassName ?? string.Empty,
                    nodeBounds,
                    name.Length,
                    UiaSemanticRoleClassifier.Classify(name)));
            }
        }
        catch (ElementNotAvailableException)
        {
            return;
        }

        AutomationElement? child;
        try
        {
            child = TreeWalker.RawViewWalker.GetFirstChild(element);
        }
        catch (ElementNotAvailableException)
        {
            return;
        }
        while (child is not null && nodes.Count < MaximumNodes)
        {
            Append(child, depth + 1, nodes, cancellationToken);
            try
            {
                child = TreeWalker.RawViewWalker.GetNextSibling(child);
            }
            catch (ElementNotAvailableException)
            {
                break;
            }
        }
    }
}
#endif
