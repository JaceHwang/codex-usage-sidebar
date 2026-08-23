using System.Text.Json;

namespace CodexUsageSidebar.Windows.Tests;

[TestClass]
public sealed class CompatibilityContractsTests
{
    [TestMethod]
    public void CompatibilityDecisionKeepsSemanticProfileAndSafeDockResultsSeparate()
    {
        var decision = new CompatibilityDecision(
            SemanticCompatibility.Valid,
            ProfileCompatibility.FallbackLocked,
            SafeDockPlacement.Titlebar,
            CompatibilityFailureCode.UiaUnavailable);

        Assert.AreEqual(SemanticCompatibility.Valid, decision.Semantic);
        Assert.AreEqual(ProfileCompatibility.FallbackLocked, decision.Profile);
        Assert.AreEqual(SafeDockPlacement.Titlebar, decision.Placement);
        Assert.AreEqual(CompatibilityFailureCode.UiaUnavailable, decision.FailureCode);
    }

    [TestMethod]
    public void CompatibilityFailureCodesCoverEveryUnsafeReconciliationBoundary()
    {
        var expected = new[]
        {
            CompatibilityFailureCode.MissingCodexWindow,
            CompatibilityFailureCode.MissingQuotaSnapshot,
            CompatibilityFailureCode.UiaUnavailable,
            CompatibilityFailureCode.InvalidCaptionControls,
            CompatibilityFailureCode.MissingToolbar,
            CompatibilityFailureCode.AmbiguousToolbar,
            CompatibilityFailureCode.MissingTitle,
            CompatibilityFailureCode.AmbiguousTitle,
            CompatibilityFailureCode.MissingAnchor,
            CompatibilityFailureCode.AmbiguousAnchor,
            CompatibilityFailureCode.InvalidGeometry,
            CompatibilityFailureCode.NoCollisionFreeSlot,
            CompatibilityFailureCode.InvalidCatalog,
        };

        CollectionAssert.IsSubsetOf(expected, Enum.GetValues<CompatibilityFailureCode>());
    }

    [TestMethod]
    public void CompatibilityPreferencesPreserveFallbackLockSizeAndPlacementOffset()
    {
        var preferences = new CompatibilityPreferences(
            FallbackLocked: true,
            FallbackSize: new CompatibilitySize(200, 28),
            PlacementAnchor: CompatibilityPlacementAnchor.TrailingEdge,
            PlacementOffset: new PointD(-12, 4));

        Assert.IsTrue(preferences.FallbackLocked);
        Assert.AreEqual(new CompatibilitySize(200, 28), preferences.FallbackSize);
        Assert.AreEqual(CompatibilityPlacementAnchor.TrailingEdge, preferences.PlacementAnchor);
        Assert.AreEqual(new PointD(-12, 4), preferences.PlacementOffset);
    }

    [TestMethod]
    public async Task RuntimeStateStoreWritesOnlySanitizedReconciliationOutcome()
    {
        var directory = Path.Combine(Path.GetTempPath(), $"codex-usage-sidebar-{Guid.NewGuid():N}");
        var path = Path.Combine(directory, "runtime-state.json");
        try
        {
            var store = new RuntimeStateStore(path);
            var outcome = new RuntimeStateOutcome(
                HostRuntimeState.Visible,
                new CompatibilityDecision(
                    SemanticCompatibility.Valid,
                    ProfileCompatibility.Validated,
                    SafeDockPlacement.Titlebar,
                    CompatibilityFailureCode.None),
                DateTimeOffset.UnixEpoch);

            await store.WriteAsync(outcome, CancellationToken.None);

            using var document = JsonDocument.Parse(await File.ReadAllTextAsync(path));
            var root = document.RootElement;
            Assert.AreEqual("Visible", root.GetProperty("RuntimeState").GetString());
            Assert.AreEqual("Titlebar", root.GetProperty("Decision").GetProperty("Placement").GetString());
            Assert.IsFalse(root.TryGetProperty("Handle", out _));
            Assert.IsFalse(root.TryGetProperty("OwnerHandle", out _));
            Assert.IsFalse(root.TryGetProperty("Path", out _));
            Assert.IsFalse(root.TryGetProperty("Account", out _));
            Assert.IsFalse(root.TryGetProperty("RawText", out _));
        }
        finally
        {
            if (Directory.Exists(directory))
            {
                Directory.Delete(directory, recursive: true);
            }
        }
    }
}
