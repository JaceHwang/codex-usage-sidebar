#if WINDOWS
using System.Windows.Automation;
using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Windows;

public sealed class WindowsDiagnosticProbe(IHostWindowLocator locator)
{
    private const int MaximumNodes = 600;
    private const int MaximumDepth = 10;

    public async ValueTask<WindowsProbeReport> CaptureAsync(
        bool includeText,
        CancellationToken cancellationToken)
    {
        var host = await locator.FindAsync(cancellationToken).ConfigureAwait(false)
            ?? throw new InvalidOperationException("A visible Codex window is required for the diagnostic probe.");
        var root = AutomationElement.FromHandle(host.Handle)
            ?? throw new InvalidOperationException("Windows UI Automation could not inspect the Codex window.");
        var redactor = ProbeRedactor.Create();
        var nodes = new List<UiaProbeNode>();
        Append(root, 0, includeText, redactor, nodes, cancellationToken);
        var executablePath = Win32CodexWindowLocator.ExecutablePath(host.Handle);
        var titlebar = CodexTitlebarSelector.TryResolve(
            host.BuildIdentity,
            host.DpiScale,
            host.Bounds,
            nodes.Select(node => new UiaStructureNode(
                node.Depth,
                node.ControlType,
                node.AutomationId,
                node.ClassName,
                node.Bounds,
                node.NameLength)).ToArray());
        return new WindowsProbeReport(
            "1",
            DateTimeOffset.UtcNow,
            Environment.OSVersion.VersionString,
            includeText,
            WindowsProbeHost.From(host),
            executablePath is null ? null : redactor.Token(executablePath),
            nodes,
            titlebar);
    }

    private static void Append(
        AutomationElement element,
        int depth,
        bool includeText,
        ProbeRedactor redactor,
        List<UiaProbeNode> nodes,
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
            var name = current.Name ?? string.Empty;
            var bounds = current.BoundingRectangle;
            nodes.Add(new UiaProbeNode(
                depth,
                current.ControlType?.ProgrammaticName ?? string.Empty,
                current.AutomationId ?? string.Empty,
                current.ClassName ?? string.Empty,
                new RectD(bounds.X, bounds.Y, bounds.Width, bounds.Height),
                name.Length,
                redactor.Token(name),
                includeText ? name : null));
        }
        catch (ElementNotAvailableException)
        {
            return;
        }

        var walker = TreeWalker.RawViewWalker;
        AutomationElement? child;
        try
        {
            child = walker.GetFirstChild(element);
        }
        catch (ElementNotAvailableException)
        {
            return;
        }
        while (child is not null && nodes.Count < MaximumNodes)
        {
            Append(child, depth + 1, includeText, redactor, nodes, cancellationToken);
            try
            {
                child = walker.GetNextSibling(child);
            }
            catch (ElementNotAvailableException)
            {
                break;
            }
        }
    }
}
#endif
