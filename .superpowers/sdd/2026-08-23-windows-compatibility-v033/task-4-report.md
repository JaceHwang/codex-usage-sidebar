# Task 4 report: signed compatibility management, local controls, and safe diagnostics

## Delivered scope

- `CompatibilityPackUpdater.cs`
  - Validates bounded (512 KiB) ZIP packs containing exactly `manifest.json`, `selectors.json`, and `signature.sig`.
  - Verifies an ECDSA P-256 signature over length-delimited manifest/catalog bytes, checks the catalog SHA-256 and schema-v2 parser, and rejects non-monotonic sequences.
  - Applies a 24-hour policy and propagates the cached ETag only through the injected transport boundary. File caching uses one atomically replaced JSON entry, so a failed write leaves the prior catalog intact.
- `WindowsTrayController.cs`, `WindowsHostApplication.cs`, and `WindowsHostCoordinator.cs`
  - Adds local tray actions for status, safe-dock lock/unlock, explicit diagnostic export, and exit. The selected action is derived from the current compatibility state.
  - Lock changes are persisted through the existing safe-dock preference store; no action modifies or injects into Codex.
- `WindowsControlCommands.cs`, `RuntimeStateReader.cs`, Control `Program.cs`, and `sidebar-control-windows.ps1`
  - `status` reports only runtime state, placement, and failure code.
  - Replaces raw `probe` export with user-initiated `diagnostic <absolute-output.zip>` and rejects `-IncludeText`.
- `WindowsDiagnosticExporter.cs`
  - Atomically writes a ZIP containing only `report.json` and `summary.json`; raw node text and executable path tokens are removed. No network submission exists.

## TDD evidence

1. Red — `dotnet test plugins\codex-usage-sidebar\windows\tests\CodexUsageSidebar.Windows.Tests\CodexUsageSidebar.Windows.Tests.csproj --no-restore --filter FullyQualifiedName~CompatibilityManagementTests`
   - Failed as expected with missing `ICompatibilityPackTransport`, cache, updater, control, and diagnostic-export types.
2. Green — same focused command after the signed pack, status, and export implementation.
   - Passed: 5/5 tests.
3. Tray-policy red — same focused command after adding the state-aware tray test.
   - Failed as expected because `WindowsTrayActions` and `WindowsTrayAction` did not exist.
4. Tray-policy green — same focused command after adding the tray policy/controller.
   - Passed: 6/6 tests.

## Final verification

- Focused: `dotnet test plugins\codex-usage-sidebar\windows\tests\CodexUsageSidebar.Windows.Tests\CodexUsageSidebar.Windows.Tests.csproj --no-restore --filter FullyQualifiedName~CompatibilityManagementTests`
  - Passed: 6/6 tests.
- Control build: `dotnet build plugins\codex-usage-sidebar\windows\src\CodexUsageSidebar.Control\CodexUsageSidebar.Control.csproj --no-restore`
  - Passed: 0 warnings, 0 errors.
- Full solution (serialized to avoid MSBuild output contention): `dotnet test plugins\codex-usage-sidebar\windows\CodexUsageSidebar.Windows.sln --no-restore -m:1`
  - Passed: Core 54/54, Windows 107/107, Installer 80/80.
- Hygiene: `git diff --check`
  - Passed; Git emitted only CRLF normalization notices.

## Scope confirmation

No Task 5 packaging, release version, installer payload, or public-documentation work was changed. Tests use injected pack transport/cache/time boundaries and make no network calls.

## Fix round 1: 304 cache refresh and cumulative ZIP extraction budget

### Changed paths

- `plugins/codex-usage-sidebar/windows/src/CodexUsageSidebar.Windows/CompatibilityPackUpdater.cs`
  - On HTTP 304 with an existing valid cache, atomically replaces the cache entry with only `UpdatedAt` refreshed, preserving sequence, ETag, and catalog bytes.
  - Tracks one cumulative uncompressed ZIP extraction budget across `manifest.json`, `selectors.json`, and `signature.sig`, rejecting packs above `MaximumPackBytes` before extraction.
- `plugins/codex-usage-sidebar/windows/tests/CodexUsageSidebar.Windows.Tests/CompatibilityManagementTests.cs`
  - Adds regression coverage for the 304 refresh followed by `NotDue` on the next call.
  - Adds rejection coverage for a ZIP whose individually bounded entries exceed the total uncompressed budget.

### TDD evidence

1. Red — the focused compatibility-management suite failed 2 tests as expected: the 304 case retained the old timestamp, and the cumulative-overflow pack was accepted as `Updated`.
2. Green — the same focused suite passed 8/8 after the updater changes.

### Scope boundary

Task 5 runtime endpoint/package integration, version changes, documentation, and transport API redesign were not attempted.

### Final verification for fix round 1

- Full Windows solution: `dotnet test plugins\\codex-usage-sidebar\\windows\\CodexUsageSidebar.Windows.sln --no-restore -m:1 --logger "console;verbosity=minimal"`
  - Passed: Core 54/54, Windows 109/109, Installer 80/80.
- Hygiene: `git diff --check`
  - Passed.
