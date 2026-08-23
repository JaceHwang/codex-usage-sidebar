using CodexUsageSidebar.Core;

namespace CodexUsageSidebar.Windows.Tests;

[TestClass]
public sealed class SafeDockCompatibilityTests
{
    [TestMethod]
    public void EntersSafeDockAfterThreeUnresolvedDecisionsOverAtLeastOneSecond()
    {
        var machine = new CompatibilityStateMachine(SafeDockPreferences.Default);
        var start = DateTimeOffset.UnixEpoch;

        machine.Transition(Unresolved(), hasLiveQuota: true, hasValidCodexHost: true, start);
        machine.Transition(Unresolved(), hasLiveQuota: true, hasValidCodexHost: true, start.AddMilliseconds(500));
        var transition = machine.Transition(
            Unresolved(), hasLiveQuota: true, hasValidCodexHost: true, start.AddSeconds(1));

        Assert.AreEqual(SafeDockPlacement.Fallback, transition.Placement);
        Assert.IsTrue(transition.ShouldShowSafeDock);
    }

    [TestMethod]
    public void RecoversToTitlebarAfterThreeSafeDecisionsOverAtLeastOneSecond()
    {
        var machine = new CompatibilityStateMachine(SafeDockPreferences.Default);
        var start = DateTimeOffset.UnixEpoch;
        EnterSafeDock(machine, start);

        machine.Transition(Safe(), hasLiveQuota: true, hasValidCodexHost: true, start.AddSeconds(2));
        machine.Transition(Safe(), hasLiveQuota: true, hasValidCodexHost: true, start.AddMilliseconds(2500));
        var transition = machine.Transition(Safe(), hasLiveQuota: true, hasValidCodexHost: true, start.AddSeconds(3));

        Assert.AreEqual(SafeDockPlacement.Titlebar, transition.Placement);
        Assert.IsFalse(transition.ShouldShowSafeDock);
    }

    [TestMethod]
    public void FallbackLockPreventsRecoveryToTitlebar()
    {
        var machine = new CompatibilityStateMachine(SafeDockPreferences.Default with { FallbackLocked = true });
        var start = DateTimeOffset.UnixEpoch;

        var transition = machine.Transition(Safe(), hasLiveQuota: true, hasValidCodexHost: true, start);

        Assert.AreEqual(SafeDockPlacement.Fallback, transition.Placement);
        Assert.IsTrue(transition.ShouldShowSafeDock);
    }

    [TestMethod]
    public void SafeDockStaysBelowCaptionAndInsideNegativeOriginMultiDpiBounds()
    {
        var host = new RectD(-1920, 100, 1200, 900);
        var workArea = new RectD(-1920, 0, 1920, 1040);
        var caption = new RectD(-1920, 100, 1200, 60);

        var result = SafeDockPlacementResolver.Resolve(new SafeDockPlacementRequest(
            host,
            workArea,
            caption,
            DpiScale: 1.5,
            SafeDockPreferences.Default));

        Assert.IsNotNull(result.Frame);
        Assert.AreEqual(SafeDockSize.Standard, result.Size);
        var frame = result.Frame!.Value;
        Assert.IsTrue(frame.Y >= caption.Bottom + 12);
        Assert.IsTrue(frame.X >= host.X && frame.Right <= host.Right);
        Assert.IsTrue(frame.X >= workArea.X && frame.Right <= workArea.Right);
        Assert.IsTrue(frame.Y >= workArea.Y && frame.Bottom <= workArea.Bottom);
    }

    [TestMethod]
    public void NarrowHostUsesCompactSafeDockWhenTheStandardVisualDoesNotFit()
    {
        var result = SafeDockPlacementResolver.Resolve(new SafeDockPlacementRequest(
            new RectD(100, 100, 110, 300),
            new RectD(0, 0, 1920, 1080),
            new RectD(100, 100, 110, 40),
            DpiScale: 1,
            SafeDockPreferences.Default));

        Assert.IsNotNull(result.Frame);
        Assert.AreEqual(SafeDockSize.Compact, result.Size);
        Assert.AreEqual(SafeDockNoPlacementReason.None, result.NoPlacementReason);
    }

    [TestMethod]
    public void SavedAnchorAndDipOffsetRemainStableAcrossDpiChanges()
    {
        var preferences = new SafeDockPreferences(
            FallbackLocked: false,
            Size: SafeDockSize.Standard,
            Anchor: SafeDockAnchor.Right,
            Offset: new PointD(-12, 4));

        var atOneX = SafeDockPlacementResolver.Resolve(new SafeDockPlacementRequest(
            new RectD(0, 0, 1000, 800),
            new RectD(0, 0, 1920, 1080),
            new RectD(0, 0, 1000, 40),
            DpiScale: 1,
            preferences));
        var atOnePointFiveX = SafeDockPlacementResolver.Resolve(new SafeDockPlacementRequest(
            new RectD(0, 0, 1500, 1200),
            new RectD(0, 0, 2880, 1620),
            new RectD(0, 0, 1500, 60),
            DpiScale: 1.5,
            preferences));

        Assert.IsNotNull(atOneX.Frame);
        Assert.IsNotNull(atOnePointFiveX.Frame);
        Assert.AreEqual(atOneX.Frame!.Value.X, atOnePointFiveX.Frame!.Value.X / 1.5, 0.000001);
        Assert.AreEqual(atOneX.Frame.Value.Y, atOnePointFiveX.Frame!.Value.Y / 1.5, 0.000001);
    }

    [TestMethod]
    public async Task SavesAndLoadsFallbackLockSizeAnchorAndDipOffset()
    {
        var directory = Path.Combine(Path.GetTempPath(), $"safe-dock-{Guid.NewGuid():N}");
        var path = Path.Combine(directory, "preferences.json");
        var preferences = new SafeDockPreferences(
            FallbackLocked: true,
            Size: SafeDockSize.Compact,
            Anchor: SafeDockAnchor.Left,
            Offset: new PointD(15.5, -3));
        try
        {
            var store = new SafeDockPreferencesStore(path);
            await store.SaveAsync(preferences, CancellationToken.None);

            Assert.AreEqual(preferences, await store.LoadAsync(CancellationToken.None));
        }
        finally
        {
            if (Directory.Exists(directory)) Directory.Delete(directory, recursive: true);
        }
    }

    [TestMethod]
    public void CompactFallbackIndicatorContainsOnlyThePercentageText()
    {
        Assert.AreEqual("76%", SafeDockIndicatorText.Format(76, SafeDockSize.Compact));
    }

    [TestMethod]
    public async Task DragReleaseSnapsToASafeRailAndPersistsTheResult()
    {
        var request = new SafeDockPlacementRequest(
            new RectD(100, 100, 600, 500),
            new RectD(0, 0, 1920, 1080),
            new RectD(100, 100, 600, 40),
            DpiScale: 1,
            SafeDockPreferences.Default);
        var snapped = SafeDockDragSnapPolicy.Snap(request, new RectD(108, 196, 75, 28));
        var directory = Path.Combine(Path.GetTempPath(), $"safe-dock-snap-{Guid.NewGuid():N}");
        try
        {
            var store = new SafeDockPreferencesStore(Path.Combine(directory, "preferences.json"));
            await store.SaveAsync(snapped, CancellationToken.None);

            Assert.AreEqual(SafeDockAnchor.Left, snapped.Anchor);
            Assert.AreEqual(snapped, await store.LoadAsync(CancellationToken.None));
        }
        finally
        {
            if (Directory.Exists(directory)) Directory.Delete(directory, recursive: true);
        }
    }

    [TestMethod]
    public void SafeSemanticAndProfileDecisionRemainsInTitlebarMode()
    {
        var transition = new CompatibilityStateMachine(SafeDockPreferences.Default).Transition(
            Safe(), hasLiveQuota: true, hasValidCodexHost: true, DateTimeOffset.UnixEpoch);

        Assert.AreEqual(SafeDockPlacement.Titlebar, transition.Placement);
        Assert.IsFalse(transition.ShouldShowSafeDock);
    }

    private static void EnterSafeDock(CompatibilityStateMachine machine, DateTimeOffset start)
    {
        machine.Transition(Unresolved(), hasLiveQuota: true, hasValidCodexHost: true, start);
        machine.Transition(Unresolved(), hasLiveQuota: true, hasValidCodexHost: true, start.AddMilliseconds(500));
        machine.Transition(Unresolved(), hasLiveQuota: true, hasValidCodexHost: true, start.AddSeconds(1));
    }

    private static CompatibilityDecision Unresolved() => new(
        SemanticCompatibility.Invalid,
        ProfileCompatibility.Invalid,
        SafeDockPlacement.None,
        CompatibilityFailureCode.UiaUnavailable);

    private static CompatibilityDecision Safe() => new(
        SemanticCompatibility.Valid,
        ProfileCompatibility.Validated,
        SafeDockPlacement.Titlebar,
        CompatibilityFailureCode.None);
}
