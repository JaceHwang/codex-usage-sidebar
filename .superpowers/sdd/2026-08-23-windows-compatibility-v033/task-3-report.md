# Task 3 report: automatic safe dock, recovery, and persisted preferences

## Delivered scope

- `CompatibilityStateMachine.cs`
  - Provides deterministic three-observation/one-second safe-dock entry and recovery gates.
  - Retains `Fallback` while transient unresolved decisions continue after safe-dock entry.
  - Honors a persisted fallback lock by keeping the fallback active even for safe titlebar decisions.
- `SafeDockPlacement.cs`
  - Provides WPF-independent safe-dock preferences, atomic JSON persistence, geometry, standard/compact sizing, and explicit no-placement reasons.
  - Clamps physical frames to the intersection of the host and work area, starts below both the caption clearance and the conservative 72-DIP host clearance, and keeps offsets in DIPs.
- `OverlayVisualMetrics.cs`
  - Adds compact logo-plus-percentage visual width metrics for the placement core.
- `SafeDockCompatibilityTests.cs`
  - Covers entry, recovery, lock behavior, caption-safe negative-origin/multi-DPI placement, compact narrow-host fallback, preferences persistence, DPI-stable anchor/offset conversion, and titlebar mode.
- `WindowsHostCoordinator.cs` and `HostContracts.cs`
  - Introduce `PlacementMode` and route only threshold-gated unresolved decisions to a `SafeDock` overlay presentation.
  - Keep existing collision-free titlebar frames in `Titlebar` mode. Retained fallback remains visible during transient failures and returns to titlebar only after the state machine’s success gate.
  - Receive persisted preference updates from a safe-dock overlay and apply them before the next reconciliation.
- `WpfOverlaySurface.cs` and `WindowsHostApplication.cs`
  - Load preferences and runtime state from the per-user local data directory, pass them into the coordinator, render compact fallback with percentage-only text, and constrain release drag to a top/left/right rail preference.

## TDD evidence

1. Red — `dotnet test plugins\codex-usage-sidebar\windows\tests\CodexUsageSidebar.Windows.Tests\CodexUsageSidebar.Windows.Tests.csproj --filter FullyQualifiedName~SafeDockCompatibilityTests`
   - Failed as expected at compile time: `CompatibilityStateMachine` did not exist (`CS0246`). This proved the new behavior was absent before production code was added.
2. First green attempt — `dotnet test plugins\codex-usage-sidebar\windows\tests\CodexUsageSidebar.Windows.Tests\CodexUsageSidebar.Windows.Tests.csproj --no-restore --filter FullyQualifiedName~SafeDockCompatibilityTests`
   - Failed only on a test-only named-argument casing error (`dpiScale` versus `DpiScale`, `CS1739`); no production behavior was exercised. The test typo was corrected.
3. Green — same focused command after the correction.
   - Passed: 8/8 tests.
4. Windows regression — `dotnet test plugins\codex-usage-sidebar\windows\tests\CodexUsageSidebar.Windows.Tests\CodexUsageSidebar.Windows.Tests.csproj --no-restore`
   - Passed: 88/88 tests.
5. Full solution — `dotnet test plugins\codex-usage-sidebar\windows\CodexUsageSidebar.Windows.sln --no-restore`
   - Passed: Core 54/54, Installer 80/80, Windows 88/88 tests.
6. Hygiene — `git diff --check`
   - Passed with no whitespace errors. Git emitted only its repository line-ending normalization notice.

7. Red — `dotnet test plugins\codex-usage-sidebar\windows\tests\CodexUsageSidebar.Windows.Tests\CodexUsageSidebar.Windows.Tests.csproj --no-restore --filter "FullyQualifiedName~ShowsSafeDockAfterThreeUnresolvedLiveQuotaReconciliations|FullyQualifiedName~RecoversFromSafeDockOnlyAfterThreeValidatedTitlebarReconciliations|FullyQualifiedName~UserFallbackLockKeepsAValidatedTitlebarInSafeDock|FullyQualifiedName~CompactFallbackIndicatorContainsOnlyThePercentageText|FullyQualifiedName~DragReleaseSnapsToASafeRailAndPersistsTheResult"`
   - Failed as expected at compile time because `PlacementMode`, the presentation mode property, compact text policy, drag-snap policy, and coordinator preference constructor were absent.
8. Green — same focused command after adding the coordinator mode/gate integration and pure compact/snap policies.
   - Passed: 5/5 tests.
9. Persistence red — `dotnet test plugins\codex-usage-sidebar\windows\tests\CodexUsageSidebar.Windows.Tests\CodexUsageSidebar.Windows.Tests.csproj --no-restore --filter FullyQualifiedName~DragUpdatedPreferencesArePersistedAndAppliedToTheNextReconciliation`
   - Failed as expected: the recording store received `null` because the overlay preference event was deliberately not yet subscribed by the coordinator.
10. Persistence green — focused coordinator/safe-dock suite after subscribing the event and updating the state machine.
    - Passed: 6/6 tests.
11. Regression diagnostic — full Windows test project initially failed only `HidesOverlayWhenNoCollisionFreeTitlebarSlotExists`: no-slot reconciliation returned `DeviceValidationRequired` rather than its established `Hidden` state.
    - Root cause: the new shared unresolved handler discarded the former no-slot state distinction. The handler now accepts the caller’s unresolved state while still showing safe dock after the threshold.
12. Regression green — `dotnet test plugins\codex-usage-sidebar\windows\tests\CodexUsageSidebar.Windows.Tests\CodexUsageSidebar.Windows.Tests.csproj --no-restore`
    - Passed: 94/94 tests.
13. WPF build — `dotnet build plugins\codex-usage-sidebar\windows\src\CodexUsageSidebar.Windows\CodexUsageSidebar.Windows.csproj --no-restore -f net8.0-windows10.0.19041.0`
    - Passed: 0 warnings, 0 errors.
14. Full solution — `dotnet test plugins\codex-usage-sidebar\windows\CodexUsageSidebar.Windows.sln --no-restore`
    - Passed: Core 54/54, Installer 80/80, Windows 94/94 tests.

## Completion notes

- WPF’s passive-window policy is unchanged; safe-dock drag uses pointer capture and snaps only on release, without activating the overlay or persisting a free position.
- The WPF surface refreshes safe-dock geometry from the owner monitor’s work area before drawing, so runtime placement remains work-area clamped even though core tests use injected rectangles.

## Commit

`96a7df2` — `Add safe dock compatibility core`.

`574c591` — `Complete automatic Windows safe dock`.

## Final verification

- Focused: `dotnet test plugins\codex-usage-sidebar\windows\tests\CodexUsageSidebar.Windows.Tests\CodexUsageSidebar.Windows.Tests.csproj --no-restore --filter "FullyQualifiedName~SafeDockCompatibilityTests|FullyQualifiedName~ShowsSafeDockAfterThreeUnresolvedLiveQuotaReconciliations|FullyQualifiedName~RecoversFromSafeDockOnlyAfterThreeValidatedTitlebarReconciliations|FullyQualifiedName~UserFallbackLockKeepsAValidatedTitlebarInSafeDock|FullyQualifiedName~DragUpdatedPreferencesArePersistedAndAppliedToTheNextReconciliation"`
  - Passed: 14/14 tests.
- Full: `dotnet test plugins\codex-usage-sidebar\windows\CodexUsageSidebar.Windows.sln --no-restore`
  - Passed: Core 54/54, Installer 80/80, Windows 94/94 tests.

## Fix round 1: physical geometry and verified caption bounds

### Changed paths

- `WindowsCoordinateSpace.cs`
  - Keeps `GetWindowRect` coordinates unchanged because PerMonitorV2 window rectangles are already physical screen pixels.
  - Adds the testable verified-caption policy: only one finite, host-contained, top-band candidate marked verified is retained; no candidate produces no caption assertion.
- `Win32CodexWindowLocator.cs`
  - Captures monitor work area with `MonitorFromWindow`/`GetMonitorInfo` in the same physical coordinate space.
  - Queries the exact `ChromeNodeCaptionButtonContainer` UIA pane and marks it verified only when it contains exactly the four expected caption button IDs/classes. The resulting physical caption bounds are preserved in `HostWindowSnapshot`; unavailable or ambiguous UIA data remains `null`.
- `WpfOverlaySurface.cs`
  - Retains the coordinator-provided physical work area for safe dock layout and uses monitor probing only as a fallback. Caption geometry continues to flow unchanged through the safe-dock request.
- `Win32CodexWindowLocatorTests.cs` and `HostCoordinatorTests.cs`
  - Add physical PerMonitorV2 conversion, verified/unverified caption, and 125% DPI safe-dock production-path coverage.

### TDD evidence

1. Red — `dotnet test plugins\codex-usage-sidebar\windows\tests\CodexUsageSidebar.Windows.Tests\CodexUsageSidebar.Windows.Tests.csproj --no-restore --filter "FullyQualifiedName~Win32CodexWindowLocatorTests|FullyQualifiedName~SafeDockUsesPhysicalHostCaptionAndWorkAreaAtOneHundredTwentyFivePercent"`
   - Failed at compile time as expected because `HostWindowGeometry` did not yet exist. The changed raw-rectangle expectation also captured the pre-fix double-scale defect.
2. Green — same focused command after adding physical geometry validation and production locator work-area/caption acquisition.
   - Passed: 3/3 tests.
3. Caption-verification red — `dotnet test plugins\codex-usage-sidebar\windows\tests\CodexUsageSidebar.Windows.Tests\CodexUsageSidebar.Windows.Tests.csproj --no-restore --filter FullyQualifiedName~DoesNotPreserveAnUnverifiedCaptionContainer`
   - Failed at compile time as expected because a caption candidate did not carry verification state.
4. Caption-verification green — focused physical/caption/coordinator command after requiring all four verified caption buttons in production.
   - Passed: 4/4 tests.
5. Windows build — `dotnet build plugins\codex-usage-sidebar\windows\src\CodexUsageSidebar.Windows\CodexUsageSidebar.Windows.csproj --no-restore -f net8.0-windows10.0.19041.0`
   - Passed: 0 warnings, 0 errors.
6. Windows regression — `dotnet test plugins\codex-usage-sidebar\windows\tests\CodexUsageSidebar.Windows.Tests\CodexUsageSidebar.Windows.Tests.csproj --no-restore`
   - Passed: 97/97 tests.
7. Full solution — `dotnet test plugins\codex-usage-sidebar\windows\CodexUsageSidebar.Windows.sln --no-restore`
   - Completed successfully; Core 54/54 and Windows 97/97 reported. Direct installer verification also passed: 80/80 tests.
8. Hygiene — `git diff --check`
   - Passed with no whitespace errors; Git emitted only repository line-ending normalization notices.

### Commit

`f173701` — `Fix safe dock physical geometry`.
