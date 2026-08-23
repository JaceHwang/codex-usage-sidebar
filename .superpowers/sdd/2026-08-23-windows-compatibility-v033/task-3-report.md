# Task 3 report: core safe-dock state and geometry slice

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

## Deferred exact scope

Per the user-directed core-slice boundary, this commit does **not** modify `WindowsHostCoordinator` or `WpfOverlaySurface`.

- The coordinator still needs to consume `CompatibilityStateMachine`, select the safe-dock frame only after the entry gate, retain an existing fallback presentation across transient scanner failures, and use the recovery gate before restoring its unchanged titlebar placement.
- The WPF surface still needs to render the compact text-only percentage layout and send pointer drag/release events through a dedicated preference-update/persistence channel that snaps only to the top, left, and right rails without activation.
- Runtime wiring still needs to load/save `SafeDockPreferencesStore` at the existing per-user runtime path and supply the monitor work area to the coordinator’s safe-dock request.

## Commit

`96a7df2` — `Add safe dock compatibility core`.
