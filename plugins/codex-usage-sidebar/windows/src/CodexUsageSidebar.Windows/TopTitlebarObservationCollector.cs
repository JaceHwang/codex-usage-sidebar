using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Windows;

public static class TopTitlebarObservationCollector
{
    public const int MaximumObservedNodes = 256;

    public static IReadOnlyList<UiaStructureNode> Normalize(IReadOnlyList<UiaStructureNode> observed)
    {
        ArgumentNullException.ThrowIfNull(observed);
        var nodes = new List<UiaStructureNode>(Math.Min(observed.Count, MaximumObservedNodes));
        var seen = new HashSet<(string ControlType, string AutomationId, string ClassName, RectD Bounds)>();
        foreach (var node in observed)
        {
            if (nodes.Count == MaximumObservedNodes) break;
            if (!UiaTraversalBudget.HasFiniteBounds(node.Bounds)) continue;
            if (seen.Add((node.ControlType, node.AutomationId, node.ClassName, node.Bounds)))
            {
                nodes.Add(node);
            }
        }
        return nodes;
    }
}
