#if WINDOWS
using System.Windows.Automation;
using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Windows;

public sealed class ValidatedUiaTitlebarScanner : ITitlebarScanner
{
    private const string CaptionContainerClass = "ChromeNodeCaptionButtonContainer";
    private const int MaximumDirectChildren = 64;
    private const int MaximumCandidateButtons = 1024;
    private const int MaximumRightPaneAncestorDepth = 8;
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
    private static readonly Condition ButtonCondition = new PropertyCondition(
        AutomationElement.ControlTypeProperty,
        ControlType.Button);
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

        var nodes = QueryValidatedStructure(root, host.Bounds, host.DpiScale, cancellationToken);
        var snapshot = CodexTitlebarSelector.TryResolve(
            host.BuildIdentity,
            host.DpiScale,
            host.Bounds,
            nodes);
        return snapshot ?? throw new WindowsDeviceValidationRequiredException(host.BuildIdentity);
    }

    private static IReadOnlyList<UiaStructureNode> QueryValidatedStructure(
        AutomationElement root,
        RectD hostBounds,
        double dpiScale,
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

        var openLocationButtons = DiscoverOpenLocationSeeds(root, hostBounds, dpiScale, cancellationToken);
        foreach (var openLocation in openLocationButtons)
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

        AddRightPaneStructures(root, openLocationButtons, dpiScale, nodes, cancellationToken);

        return nodes;
    }

    private static IReadOnlyList<AutomationElement> DiscoverOpenLocationSeeds(
        AutomationElement root,
        RectD hostBounds,
        double dpiScale,
        CancellationToken cancellationToken)
    {
        var seeds = new List<AutomationElement>();
        var seen = new HashSet<OpenLocationSeedIdentity>();
        AddOpenLocationSeeds(root.FindAll(TreeScope.Descendants, OpenLocationCondition), seeds, seen);

        AutomationElementCollection buttons;
        try
        {
            buttons = root.FindAll(TreeScope.Descendants, ButtonCondition);
        }
        catch (ElementNotAvailableException)
        {
            return seeds;
        }
        if (buttons.Count > MaximumCandidateButtons)
        {
            return seeds;
        }

        foreach (AutomationElement button in buttons)
        {
            cancellationToken.ThrowIfCancellationRequested();
            RectD bounds;
            string controlType;
            string className;
            try
            {
                var current = button.Current;
                var rectangle = current.BoundingRectangle;
                bounds = new RectD(rectangle.X, rectangle.Y, rectangle.Width, rectangle.Height);
                controlType = current.ControlType?.ProgrammaticName ?? string.Empty;
                className = current.ClassName ?? string.Empty;
            }
            catch (ElementNotAvailableException)
            {
                continue;
            }

            if (!OpenLocationSeedCandidatePolicy.IsCandidate(
                controlType,
                className,
                bounds,
                hostBounds,
                dpiScale))
            {
                continue;
            }
            AddOpenLocationSeed(button, bounds, className, seeds, seen);
        }

        return seeds;
    }

    private static void AddOpenLocationSeeds(
        AutomationElementCollection candidates,
        List<AutomationElement> seeds,
        HashSet<OpenLocationSeedIdentity> seen)
    {
        foreach (AutomationElement candidate in candidates)
        {
            RectD bounds;
            string className;
            try
            {
                var current = candidate.Current;
                var rectangle = current.BoundingRectangle;
                bounds = new RectD(rectangle.X, rectangle.Y, rectangle.Width, rectangle.Height);
                className = current.ClassName ?? string.Empty;
            }
            catch (ElementNotAvailableException)
            {
                continue;
            }
            AddOpenLocationSeed(candidate, bounds, className, seeds, seen);
        }
    }

    private static void AddOpenLocationSeed(
        AutomationElement candidate,
        RectD bounds,
        string className,
        List<AutomationElement> seeds,
        HashSet<OpenLocationSeedIdentity> seen)
    {
        var identity = new OpenLocationSeedIdentity(
            bounds.X,
            bounds.Y,
            bounds.Width,
            bounds.Height,
            className);
        if (seen.Add(identity))
        {
            seeds.Add(candidate);
        }
    }

    private readonly record struct OpenLocationSeedIdentity(
        double X,
        double Y,
        double Width,
        double Height,
        string ClassName);

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
        IReadOnlyList<AutomationElement> openLocationButtons,
        double dpiScale,
        List<UiaStructureNode> nodes,
        CancellationToken cancellationToken)
    {
        AutomationElementCollection buttons;
        try
        {
            buttons = root.FindAll(TreeScope.Descendants, ButtonCondition);
        }
        catch (ElementNotAvailableException)
        {
            return;
        }
        if (buttons.Count > MaximumCandidateButtons)
        {
            return;
        }
        foreach (AutomationElement openLocation in openLocationButtons)
        {
            RectD openLocationBounds;
            try
            {
                var bounds = openLocation.Current.BoundingRectangle;
                openLocationBounds = new RectD(bounds.X, bounds.Y, bounds.Width, bounds.Height);
            }
            catch (ElementNotAvailableException)
            {
                continue;
            }
            foreach (AutomationElement button in buttons)
            {
                cancellationToken.ThrowIfCancellationRequested();
                RectD buttonBounds;
                string controlType;
                string className;
                try
                {
                    var current = button.Current;
                    var bounds = current.BoundingRectangle;
                    buttonBounds = new RectD(bounds.X, bounds.Y, bounds.Width, bounds.Height);
                    controlType = current.ControlType?.ProgrammaticName ?? string.Empty;
                    className = current.ClassName ?? string.Empty;
                }
                catch (ElementNotAvailableException)
                {
                    continue;
                }
                if (!RightToolbarCandidatePolicy.IsCandidate(
                    openLocationBounds, buttonBounds, controlType, className, dpiScale))
                {
                    continue;
                }
                var surface = TryGetParent(button);
                if (surface is null)
                {
                    continue;
                }
                var surfaceChildren = DirectChildren(surface, cancellationToken);
                if (surfaceChildren.Count(child =>
                        ClassNameContains(child, RightToolbarClassMarker)
                        && ClassNameContains(child, RightToolbarOverflowMarker)) != 1)
                {
                    continue;
                }
                var container = TryGetParent(surface);
                var rightPane = container is null
                    ? null
                    : TryFindAncestor(
                        container,
                        element => ClassNameContains(element, "relative z-[41] h-full")
                            && ClassNameContains(element, "min-w-0 shrink-0 overflow-visible"),
                        MaximumRightPaneAncestorDepth);
                if (container is null || rightPane is null)
                {
                    continue;
                }
                AddNode(rightPane, 15, nodes);
                AddNode(container, 16, nodes);
                AddNode(surface, 17, nodes);
                foreach (var child in surfaceChildren)
                {
                    AddNode(child, 18, nodes);
                }
            }
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

    private static AutomationElement? TryFindAncestor(
        AutomationElement start,
        Func<AutomationElement, bool> predicate,
        int maximumDepth)
    {
        var current = start;
        for (var depth = 0; depth <= maximumDepth && current is not null; depth++)
        {
            if (predicate(current)) return current;
            current = TryGetParent(current);
        }
        return null;
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
