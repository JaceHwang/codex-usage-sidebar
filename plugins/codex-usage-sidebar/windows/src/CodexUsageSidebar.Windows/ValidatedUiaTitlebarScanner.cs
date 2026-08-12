#if WINDOWS
using System.Windows.Automation;
using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Windows;

public sealed class ValidatedUiaTitlebarScanner : ITitlebarScanner
{
    private const string CaptionContainerClass = "ChromeNodeCaptionButtonContainer";
    private const int MaximumDirectChildren = 64;
    private const int MaximumCandidateGroups = 1024;
    private const string TitleGroupClassMarker = "text-md flex min-w-0 items-center";
    private const string RightToolbarClassMarker = "hide-scrollbar flex h-full min-w-0 flex-1";
    private const string RightToolbarOverflowMarker = "overflow-x-auto overflow-y-hidden";
    private static readonly TimeSpan ScanTimeout = TimeSpan.FromSeconds(2);
    private static readonly Condition CaptionContainerCondition = new AndCondition(
        new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Pane),
        new PropertyCondition(AutomationElement.ClassNameProperty, CaptionContainerClass));
    private static readonly Condition OpenLocationCondition = new AndCondition(
        new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button),
        new OrCondition(UiaSemanticRoleClassifier.SupportedExactNames
            .Select(name => (Condition)new PropertyCondition(
                AutomationElement.NameProperty,
                name,
                PropertyConditionFlags.IgnoreCase))
            .ToArray()));
    private static readonly Condition GroupCondition = new PropertyCondition(
        AutomationElement.ControlTypeProperty,
        ControlType.Group);
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

        var nodes = QueryValidatedStructure(root, cancellationToken);
        var snapshot = CodexTitlebarSelector.TryResolve(
            host.BuildIdentity,
            host.DpiScale,
            host.Bounds,
            nodes);
        return snapshot ?? throw new WindowsDeviceValidationRequiredException(host.BuildIdentity);
    }

    private static IReadOnlyList<UiaStructureNode> QueryValidatedStructure(
        AutomationElement root,
        CancellationToken cancellationToken)
    {
        var nodes = new List<UiaStructureNode>();
        var captionContainers = root.FindAll(TreeScope.Descendants, CaptionContainerCondition);
        foreach (AutomationElement container in captionContainers)
        {
            cancellationToken.ThrowIfCancellationRequested();
            AddNode(container, 3, nodes);
            AddDirectChildren(container, 4, nodes, cancellationToken);
        }

        var openLocationButtons = root.FindAll(TreeScope.Descendants, OpenLocationCondition);
        foreach (AutomationElement openLocation in openLocationButtons)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var contentGroup = TryGetParent(openLocation);
            var toolbar = contentGroup is null ? null : TryGetParent(contentGroup);
            if (contentGroup is null || toolbar is null)
            {
                continue;
            }
            AddNode(toolbar, 14, nodes);
            AddNode(contentGroup, 15, nodes);
            AddDirectChildren(contentGroup, 16, nodes, cancellationToken);
            AddTitleChildren(contentGroup, nodes, cancellationToken);
        }

        AddRightPaneStructures(root, nodes, cancellationToken);

        return nodes;
    }

    private static void AddTitleChildren(
        AutomationElement contentGroup,
        List<UiaStructureNode> nodes,
        CancellationToken cancellationToken)
    {
        var titleGroups = DirectChildren(contentGroup, cancellationToken)
            .Where(element => ClassNameContains(element, TitleGroupClassMarker))
            .ToArray();
        foreach (var titleGroup in titleGroups)
        {
            AddDirectChildren(titleGroup, 17, nodes, cancellationToken);
        }
    }

    private static void AddRightPaneStructures(
        AutomationElement root,
        List<UiaStructureNode> nodes,
        CancellationToken cancellationToken)
    {
        AutomationElementCollection groups;
        try
        {
            groups = root.FindAll(TreeScope.Descendants, GroupCondition);
        }
        catch (ElementNotAvailableException)
        {
            return;
        }
        if (groups.Count > MaximumCandidateGroups)
        {
            return;
        }
        foreach (AutomationElement header in groups)
        {
            cancellationToken.ThrowIfCancellationRequested();
            if (!ClassNameContains(header, RightToolbarClassMarker)
                || !ClassNameContains(header, RightToolbarOverflowMarker))
            {
                continue;
            }
            var surface = TryGetParent(header);
            var container = surface is null ? null : TryGetParent(surface);
            var rightPane = container is null ? null : TryGetParent(container);
            if (surface is null || container is null || rightPane is null)
            {
                continue;
            }
            AddNode(rightPane, 15, nodes);
            AddNode(container, 16, nodes);
            AddNode(surface, 17, nodes);
            AddDirectChildren(surface, 18, nodes, cancellationToken);
        }
    }

    private static bool ClassNameContains(AutomationElement element, string marker)
    {
        try
        {
            return (element.Current.ClassName ?? string.Empty).Contains(marker, StringComparison.Ordinal);
        }
        catch (ElementNotAvailableException)
        {
            return false;
        }
    }

    private static AutomationElement? TryGetParent(AutomationElement element)
    {
        try
        {
            return TreeWalker.RawViewWalker.GetParent(element);
        }
        catch (ElementNotAvailableException)
        {
            return null;
        }
    }

    private static void AddDirectChildren(
        AutomationElement parent,
        int depth,
        List<UiaStructureNode> nodes,
        CancellationToken cancellationToken)
    {
        foreach (var child in DirectChildren(parent, cancellationToken))
        {
            AddNode(child, depth, nodes);
        }
    }

    private static IReadOnlyList<AutomationElement> DirectChildren(
        AutomationElement parent,
        CancellationToken cancellationToken)
    {
        var children = new List<AutomationElement>();
        AutomationElement? child;
        try
        {
            child = TreeWalker.RawViewWalker.GetFirstChild(parent);
        }
        catch (ElementNotAvailableException)
        {
            return children;
        }
        while (child is not null && children.Count < MaximumDirectChildren)
        {
            cancellationToken.ThrowIfCancellationRequested();
            children.Add(child);
            try
            {
                child = TreeWalker.RawViewWalker.GetNextSibling(child);
            }
            catch (ElementNotAvailableException)
            {
                break;
            }
        }
        return children;
    }

    private static void AddNode(
        AutomationElement element,
        int depth,
        List<UiaStructureNode> nodes)
    {
        try
        {
            var current = element.Current;
            var bounds = current.BoundingRectangle;
            var name = current.Name ?? string.Empty;
            var nodeBounds = new RectD(bounds.X, bounds.Y, bounds.Width, bounds.Height);
            if (!UiaTraversalBudget.HasFiniteBounds(nodeBounds))
            {
                return;
            }
            nodes.Add(new UiaStructureNode(
                depth,
                current.ControlType?.ProgrammaticName ?? string.Empty,
                current.AutomationId ?? string.Empty,
                current.ClassName ?? string.Empty,
                nodeBounds,
                name.Length,
                UiaSemanticRoleClassifier.Classify(name)));
        }
        catch (ElementNotAvailableException)
        {
        }
    }
}
#endif
