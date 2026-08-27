using System.Text.Json;
using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Windows.Tests;

[TestClass]
public sealed class TopTitlebarObservationCollectorTests
{
    [TestMethod]
    public void NormalizesABoundedWrappedTopTitlebarObservationBeforeResolution()
    {
        var fixture = JsonSerializer.Deserialize<Fixture>(
            File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "contracts", "uia", "windows-codex-151.0.7922.76-default-200.json")),
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true })!;
        var observed = fixture.Nodes.Select(node => node with
        {
            Depth = node.Depth >= 15 ? node.Depth + 2 : node.Depth,
            ClassName = string.Join(' ', node.ClassName.Split(' ', StringSplitOptions.RemoveEmptyEntries).Reverse()),
        }).Append(new UiaStructureNode(20, "ControlType.Group", "", "ignored", new RectD(double.NaN, 0, 1, 1), 0)).ToArray();

        var normalized = TopTitlebarObservationCollector.Normalize(observed);
        var result = CodexTitlebarSelector.TryResolve(
            fixture.BuildIdentity, fixture.DpiScale, fixture.HostBounds, normalized);

        Assert.AreEqual(fixture.Nodes.Count, normalized.Count);
        Assert.IsNotNull(result);
    }

    private sealed record Fixture(
        string BuildIdentity,
        double DpiScale,
        RectD HostBounds,
        IReadOnlyList<UiaStructureNode> Nodes);
}
