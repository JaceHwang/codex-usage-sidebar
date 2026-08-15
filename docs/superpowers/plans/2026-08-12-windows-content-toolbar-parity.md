# Windows Content Toolbar Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Anchor the Windows quota indicator to the active content toolbar's Open Location control, keep it stable through host geometry changes, and match the macOS v0.2.3 detail header.

**Architecture:** A build-gated UIA selector consumes a new default-redacted content-toolbar fixture and returns physical anchor/obstacle geometry. A monotonic stabilization policy retains only a still-safe last valid placement for 750 milliseconds, while the coordinator scans at 100 milliseconds and WPF renders the macOS dimensions and badge layout.

**Tech Stack:** .NET 8, C# 12, WPF, Win32/UI Automation, MSTest, PowerShell 5.1, Python manifest verification.

## Global Constraints

- Windows 11 AMD64/x64 only; ARM64 is outside v0.3.0-beta.1.
- Codex build `151.0.7922.76` is the only enabled selector identity.
- Unknown or unsafe UIA structure hides; never guess coordinates.
- Device payload remains nonpublishable and no setup/release asset is emitted.
- Do not modify macOS v0.2.3 sources, assets, DMG, or release assets.

---

### Task 1: Capture and Minimize the Content Toolbar Fixture

**Files:**
- Modify: `plugins/codex-usage-sidebar/contracts/uia/windows-codex-151.0.7922.76-default-200.json`
- Modify: `plugins/codex-usage-sidebar/windows/src/CodexUsageSidebar.Windows/WindowsDiagnosticProbe.cs`
- Test: `plugins/codex-usage-sidebar/windows/tests/CodexUsageSidebar.Windows.Tests/WindowsDiagnosticProbeTests.cs`

**Interfaces:**
- Consumes: default-redacted `probe` command and the disposable current Codex task.
- Produces: a sanitized fixture containing the unique center toolbar/Open Location structure and expected physical anchor geometry.

- [ ] Add a failing privacy/shape test requiring the fixture to contain the content-toolbar branch, no raw names, and no caption boundary as the expected anchor.
- [ ] Run the focused diagnostic test and observe the missing content-toolbar branch failure.
- [ ] Extend only the diagnostic traversal depth/node budget needed for the measured toolbar, capture the default-redacted report, and minimize it to the required branch.
- [ ] Run the focused test and `python -m json.tool` to verify green and valid JSON.
- [ ] Commit the sanitized fixture and diagnostic test.

### Task 2: Select the Semantic Content Toolbar Anchor

**Files:**
- Modify: `plugins/codex-usage-sidebar/windows/src/CodexUsageSidebar.Windows/CodexTitlebarSelector.cs`
- Modify: `plugins/codex-usage-sidebar/windows/src/CodexUsageSidebar.Windows/HostContracts.cs`
- Modify: `plugins/codex-usage-sidebar/windows/tests/CodexUsageSidebar.Windows.Tests/CodexTitlebarSelectorTests.cs`

**Interfaces:**
- Consumes: `IReadOnlyList<UiaStructureNode>` from Task 1.
- Produces: `TitlebarSnapshot` whose preferred trailing edge is the measured Open Location left edge and whose obstacles are eligible content-toolbar controls.

- [ ] Add failing tests for exact semantic selection, unknown build, missing/duplicate anchor, off-host geometry, and rejection of caption-only trees.
- [ ] Run the focused selector tests and verify failures identify the old caption fallback.
- [ ] Implement the minimum build-gated structural/token/geometry match without persisting raw text or allowing the caption container to anchor.
- [ ] Run selector tests and verify all cases pass.
- [ ] Commit selector and fixture contract changes.

### Task 3: Stabilize Move and Resize Reconciliation

**Files:**
- Modify: `plugins/codex-usage-sidebar/windows/src/CodexUsageSidebar.Windows/ValidatedTitlebarCache.cs`
- Modify: `plugins/codex-usage-sidebar/windows/src/CodexUsageSidebar.Windows/ValidatedUiaTitlebarScanner.cs`
- Modify: `plugins/codex-usage-sidebar/windows/src/CodexUsageSidebar.Windows/WindowsHostCoordinator.cs`
- Modify: `plugins/codex-usage-sidebar/windows/src/CodexUsageSidebar.Windows/WindowsHostApplication.cs`
- Test: `plugins/codex-usage-sidebar/windows/tests/CodexUsageSidebar.Windows.Tests/ValidatedTitlebarCacheTests.cs`
- Test: `plugins/codex-usage-sidebar/windows/tests/CodexUsageSidebar.Windows.Tests/WindowsHostCoordinatorTests.cs`

**Interfaces:**
- Consumes: physical `HostWindowSnapshot` and valid `TitlebarSnapshot`.
- Produces: 100-millisecond rescan/reposition and monotonic last-valid retention capped at 750 milliseconds.

- [ ] Add failing tests for immediate resize reposition, transient invalid scan retention, expiry hiding, build/DPI/handle invalidation, and unsafe retained-frame rejection.
- [ ] Run the focused cache/coordinator tests and verify expected failures.
- [ ] Implement monotonic stabilization, eliminate the pre-scan hide that causes flashing, and change the runtime reconcile interval from 250 to 100 milliseconds.
- [ ] Run focused and complete Windows tests.
- [ ] Commit stabilization changes.

### Task 4: Match macOS Indicator and Detail Header

**Files:**
- Modify: `plugins/codex-usage-sidebar/windows/src/CodexUsageSidebar.Windows/WpfOverlaySurface.cs`
- Modify: `plugins/codex-usage-sidebar/windows/src/CodexUsageSidebar.Windows/WindowsHostCoordinator.cs`
- Modify: `plugins/codex-usage-sidebar/windows/src/CodexUsageSidebar.Core/PresentationPolicies.cs`
- Test: `plugins/codex-usage-sidebar/windows/tests/CodexUsageSidebar.Core.Tests/PresentationPolicyTests.cs`
- Test: `plugins/codex-usage-sidebar/windows/tests/CodexUsageSidebar.Windows.Tests/WpfOverlaySurfaceTests.cs`

**Interfaces:**
- Consumes: overlay presentation and localized quota detail content.
- Produces: `164 x 46` logical indicator and an approximately 300-pixel detail card with a nonwrapping blue version badge after the title.

- [ ] Add failing policy/layout tests for indicator dimensions, header column order, badge minimum width/nonwrapping, title/percentage sizing, and progress spacing.
- [ ] Run focused tests and verify they fail against the current `208 x 40`/compressed badge implementation.
- [ ] Implement only the measured macOS sizing, spacing, and badge layout while preserving theme brushes and no-activate window styles.
- [ ] Run focused and complete Core/Windows tests.
- [ ] Commit visual parity changes.

### Task 5: Build, Install, and Verify the Real Device

**Files:**
- Modify only if a new committed selector digest is required: `scripts/install-windows-device-payload.ps1`
- Test: `tests/test-windows-device-payload.ps1`

**Interfaces:**
- Consumes: clean committed x64 source and the official SHA-pinned Codex runtime.
- Produces: a provenance-bound current-user `device-test` payload and real-device evidence.

- [ ] Run all 74+ .NET tests, PowerShell 5.1 device tests, payload manifest tests, workflow gate, macOS freeze gate, format verification, and `git diff --check`.
- [ ] Request an independent review and resolve every Critical/Important finding.
- [ ] Commit final fixes, build the clean-HEAD payload, and atomically install it under `%LOCALAPPDATA%\CodexUsageSidebar\Current`.
- [ ] Verify restored/resized window tracking, exact 8-logical-pixel anchor gap, hover/detail, pin, foreground ownership, and fail-hidden behavior using only measured windows/UIA.
- [ ] Confirm installed manifest remains x64/device-test/nonpublishable and that no setup/release/macOS asset changed.
