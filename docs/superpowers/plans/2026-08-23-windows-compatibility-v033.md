# Windows Compatibility v0.3.3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the Windows companion remain usable across Codex titlebar changes by adding adaptive placement, an automatic safe dock fallback, signed compatibility rules, actionable status, diagnostics, and setup verification.

**Architecture:** The host produces an explicit compatibility decision rather than a binary UIA success/failure. A generic semantic resolver is first, an installed signed profile catalog is second, and an owned safe-dock overlay is the automatic final fallback. State is persisted locally so setup, control commands, and the tray present the same reason and recovery actions.

**Tech Stack:** .NET 8, WPF, Windows UI Automation, Win32, MSTest, PowerShell.

**Spec:** User-approved Windows compatibility v0.3.3 design in this Codex task.

## Global Constraints

- Support Windows 11 AMD64/x64 only; do not modify Codex or inject into its process.
- Keep all titlebar placement collision-free; unknown titlebar structure must never receive guessed titlebar coordinates.
- Unknown-but-valid Codex windows with live quota data automatically show the owned safe dock after three failures over at least one second.
- Do not collect or upload telemetry; diagnostic export must be user initiated and omit raw UI text, user paths, and window handles.
- Online compatibility data is declarative, at most 512 KiB, signed with a pinned ECDSA P-256 public key, sequence-monotonic, and atomically cached.
- Keep `selectors.json` as the payload file name and make it runtime-consumed schema v2.

---

### Task 1: Compatibility contracts and persisted state

**Files:**
- Create: `plugins/codex-usage-sidebar/windows/src/CodexUsageSidebar.Windows/CompatibilityContracts.cs`
- Create: `plugins/codex-usage-sidebar/windows/src/CodexUsageSidebar.Windows/RuntimeStateStore.cs`
- Modify: `HostContracts.cs`, `WindowsHostCoordinator.cs`, Windows tests.

- [ ] Write failing tests for explicit failure codes, state serialization without sensitive fields, and automatic fallback state transitions.
- [ ] Run the Windows test project and confirm the tests fail because the contracts/store do not exist.
- [ ] Add compatibility mode, failure code, decision, preference, runtime-status and atomic local-store interfaces.
- [ ] Change the coordinator to surface a decision and persist it after every reconciliation.
- [ ] Run focused tests, then the full solution tests.
- [ ] Commit `feat: add Windows compatibility state contracts`.

### Task 2: Adaptive UIA resolver and runtime selectors catalog

**Files:**
- Create: `AdaptiveTitlebarResolver.cs`, `CompatibilityProfileCatalog.cs`
- Modify: `ValidatedUiaTitlebarScanner.cs`, `CodexTitlebarSelector.cs`, `WindowsHostCoordinator.cs`, `selectors.json` build inputs and selector tests.

- [ ] Add fixtures/tests proving benign depth/class changes resolve and ambiguous or colliding structures do not.
- [ ] Confirm the new tests fail against the fixed-depth selector.
- [ ] Collect a bounded titlebar observation, implement semantic/geometry candidate scoring, and load schema-v2 `selectors.json` as a second resolver.
- [ ] Remove the build-identity-only coordinate fallback; return explicit failures when no safe titlebar frame exists.
- [ ] Verify focused selector tests and the full solution.
- [ ] Commit `feat: resolve Codex titlebars adaptively`.

### Task 3: Automatic safe dock, preference persistence, and non-flickering recovery

**Files:**
- Create: `SafeDockPlacement.cs`, `CompatibilityStateMachine.cs`
- Modify: `WindowsHostCoordinator.cs`, `WpfOverlaySurface.cs`, `OverlayVisualMetrics.cs`, Windows tests.

- [ ] Add failing tests for three-failure entry, three-success recovery, compact fallback on a narrow window, and caption-safe placement.
- [ ] Confirm tests fail before the state machine exists.
- [ ] Implement window-relative safe dock, standard/compact geometry, retained visibility, automatic recovery, and persisted lock/reset/size preferences.
- [ ] Add drag-and-snap behaviour restricted to top/left/right safe rails.
- [ ] Run focused tests and full solution tests.
- [ ] Commit `feat: add automatic Windows safe dock fallback`.

### Task 4: Signed compatibility update, control commands, tray, and privacy-safe diagnostics

**Files:**
- Create: `CompatibilityPackUpdater.cs`, `WindowsTrayController.cs`
- Modify: `WindowsHostApplication.cs`, `WindowsDiagnosticProbe.cs`, `WindowsProbeReport.cs`, Control `Program.cs`, `sidebar-control-windows.ps1`, tests.

- [ ] Add failing tests for valid catalog acceptance, tamper/replay/oversize rejection, local status command output, and diagnostic redaction.
- [ ] Confirm each test fails before production implementation.
- [ ] Implement ECDSA P-256 verification over a manifest/catalog pack, ETag/24-hour update policy, atomic cache rollback, state-aware control commands, and tray actions.
- [ ] Implement user-initiated diagnostic ZIP/export summary without automatic submission.
- [ ] Run focused tests and full solution tests.
- [ ] Commit `feat: add Windows compatibility management`.

### Task 5: Setup integration, package verification, and documentation

**Files:**
- Modify: installer sources, `scripts/build-windows-v032-setup.ps1` successor/renamed v0.3.3 scripts, payload verifiers, hook JSON, README and Windows docs.
- Test: installer tests and release-script verification tests.

- [ ] Add failing installer/controller tests for install-required, post-install health states, upgrade-preserved preferences, and runtime-consumed selectors payload.
- [ ] Confirm the tests fail before installer changes.
- [ ] Embed initial selector catalog/public key, wait up to ten seconds for runtime state, render localized health outcomes, and make the hook report install-required rather than silently returning.
- [ ] Update the release version/provenance chain and public docs to make setup the Windows install entry point.
- [ ] Run setup payload verification, full solution tests, public repository checks, and `git diff --check`.
- [ ] Commit `release: prepare Windows v0.3.3 compatibility setup`.

### Task 6: Real-device fixture matrix and final verification

**Files:**
- Create/modify: UIA contract fixtures, validation records, release documentation.

- [ ] Add three sampled-build wide/narrow/right-pane fixtures with 100/125/150/200% DPI transforms and Chinese/English semantic cases.
- [ ] Run every automatic suite and inspect safe-dock, semantic, profile, update, and diagnostic coverage.
- [ ] Execute the current-build Windows 11 x64 manual matrix: layout, DPI, theme, install/repair/update/uninstall, safe-dock drag, and auto recovery.
- [ ] Run full release-package verification and record only sanitized real-device evidence.
- [ ] Commit `test: validate Windows v0.3.3 compatibility matrix`.
