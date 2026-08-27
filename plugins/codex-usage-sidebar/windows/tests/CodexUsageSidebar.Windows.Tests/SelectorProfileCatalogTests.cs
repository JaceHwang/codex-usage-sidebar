using System.Text.Json;
using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Windows.Tests;

[TestClass]
public sealed class SelectorProfileCatalogTests
{
    [TestMethod]
    public void ResolvesWrapperDepthChangesAndReorderedClassTokens()
    {
        var fixture = LoadFixture();
        var adaptiveNodes = fixture.Nodes.Select(node => node with
        {
            Depth = node.Depth >= 15 ? node.Depth + 2 : node.Depth,
            ClassName = ReorderTokens(node.ClassName),
        }).ToArray();

        var result = CodexTitlebarSelector.TryResolve(
            fixture.BuildIdentity,
            fixture.DpiScale,
            fixture.HostBounds,
            adaptiveNodes);

        Assert.IsNotNull(result);
        Assert.AreEqual(fixture.Expected.OpenLocationBounds, result.OpenLocationBounds);
    }

    [TestMethod]
    public void RejectsMalformedCatalogsAndDoesNotTreatBuildIdentityAsAGate()
    {
        Assert.IsFalse(SelectorProfileCatalog.TryParse(
            "{\"schemaVersion\":2,\"profiles\":[{\"markerAliases\":{\"composer\":[\"x\"]},\"unsafe\":true}]}",
            out _));
        Assert.IsTrue(SelectorProfileCatalog.TryParse(
            "{\"schemaVersion\":2,\"profiles\":[{\"buildIdentities\":[\"known\"],\"markerAliases\":{\"composer\":[\"safe-composer\"]}}]}",
            out var catalog));

        var fixture = LoadFixture();
        var aliasedNodes = fixture.Nodes.Select(node => node with
        {
            ClassName = node.ClassName.Replace("h-token-button-composer", "safe-composer", StringComparison.Ordinal),
        }).ToArray();

        var result = CodexTitlebarSelector.TryResolve(
            "unrecognized-build",
            fixture.DpiScale,
            fixture.HostBounds,
            aliasedNodes,
            catalog);

        Assert.IsNotNull(result);
    }

    [TestMethod]
    public void RejectsCatalogsThatExceedRuntimeInputAndCollectionBounds()
    {
        var oversized = new string(' ', (512 * 1024) + 1) + "{\"schemaVersion\":2,\"profiles\":[{}]}";
        var tooManyProfiles = "{\"schemaVersion\":2,\"profiles\":[" + string.Join(',', Enumerable.Repeat("{}", 33)) + "]}";
        var tooManyBuilds = "{\"schemaVersion\":2,\"profiles\":[{\"buildIdentities\":[" + string.Join(',', Enumerable.Repeat("\"b\"", 17)) + "]}]}";
        var tooManyAliases = "{\"schemaVersion\":2,\"profiles\":[{\"markerAliases\":{\"composer\":["
            + string.Join(',', Enumerable.Range(0, 17).Select(index => "\"x" + index + "\"")) + "]}}]}";
        var longAlias = "{\"schemaVersion\":2,\"profiles\":[{\"markerAliases\":{\"composer\":[\"" + new string('x', 129) + "\"]}}]}";

        Assert.IsFalse(SelectorProfileCatalog.TryParse(oversized, out _));
        Assert.IsFalse(SelectorProfileCatalog.TryParse(tooManyProfiles, out _));
        Assert.IsFalse(SelectorProfileCatalog.TryParse(tooManyBuilds, out _));
        Assert.IsFalse(SelectorProfileCatalog.TryParse(tooManyAliases, out _));
        Assert.IsFalse(SelectorProfileCatalog.TryParse(longAlias, out _));
    }

    private static string ReorderTokens(string className) => string.Join(
        ' ',
        className.Split(' ', StringSplitOptions.RemoveEmptyEntries).Reverse());

    private static SelectorFixture LoadFixture() => JsonSerializer.Deserialize<SelectorFixture>(
        File.ReadAllText(Path.Combine(
            AppContext.BaseDirectory,
            "contracts",
            "uia",
            "windows-codex-151.0.7922.76-default-200.json")),
        new JsonSerializerOptions { PropertyNameCaseInsensitive = true })!;

    private sealed record SelectorFixture(
        string BuildIdentity,
        double DpiScale,
        RectD HostBounds,
        IReadOnlyList<UiaStructureNode> Nodes,
        ExpectedFixture Expected);

    private sealed record ExpectedFixture(RectD OpenLocationBounds);
}
