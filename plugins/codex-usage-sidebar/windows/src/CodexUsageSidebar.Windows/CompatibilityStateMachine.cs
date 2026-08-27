namespace CodexUsageSidebar.Windows;

public sealed record CompatibilityTransition(
    SafeDockPlacement Placement,
    bool ShouldShowSafeDock);

public sealed class CompatibilityStateMachine
{
    private const int RequiredObservations = 3;
    private static readonly TimeSpan MinimumObservationWindow = TimeSpan.FromSeconds(1);
    private SafeDockPreferences preferences;
    private int unresolvedCount;
    private DateTimeOffset? firstUnresolvedAt;
    private int safeCount;
    private DateTimeOffset? firstSafeAt;
    private SafeDockPlacement placement = SafeDockPlacement.None;

    public CompatibilityStateMachine(SafeDockPreferences preferences) =>
        this.preferences = preferences ?? throw new ArgumentNullException(nameof(preferences));

    public void UpdatePreferences(SafeDockPreferences value) =>
        preferences = value ?? throw new ArgumentNullException(nameof(value));

    public CompatibilityTransition Transition(
        CompatibilityDecision decision,
        bool hasLiveQuota,
        bool hasValidCodexHost,
        DateTimeOffset observedAt)
    {
        ArgumentNullException.ThrowIfNull(decision);

        if (!hasLiveQuota || !hasValidCodexHost)
        {
            ResetObservations();
            placement = SafeDockPlacement.None;
            return new CompatibilityTransition(placement, ShouldShowSafeDock: false);
        }

        if (preferences.FallbackLocked)
        {
            placement = SafeDockPlacement.Fallback;
            ResetObservations();
            return new CompatibilityTransition(placement, ShouldShowSafeDock: true);
        }

        if (IsSafe(decision))
        {
            ResetUnresolved();
            if (placement != SafeDockPlacement.Fallback)
            {
                placement = SafeDockPlacement.Titlebar;
                ResetSafe();
                return new CompatibilityTransition(placement, ShouldShowSafeDock: false);
            }

            Record(ref safeCount, ref firstSafeAt, observedAt);
            if (HasRequiredDuration(safeCount, firstSafeAt, observedAt))
            {
                placement = SafeDockPlacement.Titlebar;
                ResetSafe();
                return new CompatibilityTransition(placement, ShouldShowSafeDock: false);
            }

            return new CompatibilityTransition(SafeDockPlacement.Fallback, ShouldShowSafeDock: true);
        }

        ResetSafe();
        if (placement == SafeDockPlacement.Fallback)
        {
            return new CompatibilityTransition(SafeDockPlacement.Fallback, ShouldShowSafeDock: true);
        }

        Record(ref unresolvedCount, ref firstUnresolvedAt, observedAt);
        if (HasRequiredDuration(unresolvedCount, firstUnresolvedAt, observedAt))
        {
            placement = SafeDockPlacement.Fallback;
            ResetUnresolved();
            return new CompatibilityTransition(placement, ShouldShowSafeDock: true);
        }

        return new CompatibilityTransition(SafeDockPlacement.None, ShouldShowSafeDock: false);
    }

    private static bool IsSafe(CompatibilityDecision decision) =>
        decision.Semantic == SemanticCompatibility.Valid
        && decision.Profile == ProfileCompatibility.Validated
        && decision.Placement == SafeDockPlacement.Titlebar;

    private static void Record(ref int count, ref DateTimeOffset? firstAt, DateTimeOffset observedAt)
    {
        if (count == 0) firstAt = observedAt;
        count++;
    }

    private static bool HasRequiredDuration(int count, DateTimeOffset? firstAt, DateTimeOffset observedAt) =>
        count >= RequiredObservations
        && firstAt is not null
        && observedAt - firstAt >= MinimumObservationWindow;

    private void ResetObservations()
    {
        ResetUnresolved();
        ResetSafe();
    }

    private void ResetUnresolved()
    {
        unresolvedCount = 0;
        firstUnresolvedAt = null;
    }

    private void ResetSafe()
    {
        safeCount = 0;
        firstSafeAt = null;
    }
}
