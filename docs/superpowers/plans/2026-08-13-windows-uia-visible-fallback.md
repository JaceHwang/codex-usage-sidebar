# Windows UIA Visible Fallback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore visible v0.3.0 quota UI for the measured flat Codex title topology and provide a bounded host-relative fallback for the exact validated build.

**Architecture:** Extend the semantic selector with one exact flat-title variant. If semantic selection still fails, the coordinator may derive a physical-pixel fallback only for the authenticated Codex build `151.0.7922.76`; all other builds and invalid windows remain hidden.

**Tech Stack:** .NET 8, C#, WPF, Win32/UI Automation, MSTest, PowerShell packaging.

## Global Constraints

- Windows 11 AMD64/x64 only.
- Unknown builds remain hidden.
- The fallback is window-relative and recomputed from current host bounds and DPI; it is not an absolute screen coordinate.
- The overlay remains Codex-owned and non-activating.
- Device-test payloads remain `publishableInstaller=false` and `realDeviceValidated=false`.
- Published macOS v0.2.3 assets remain unchanged.

---

### Task 1: Exact flat-title selector

**Files:**
- Create: `plugins/codex-usage-sidebar/contracts/uia/windows-codex-151.0.7922.76-default-flat-200.json`
- Modify: `plugins/codex-usage-sidebar/windows/src/CodexUsageSidebar.Windows/CodexTitlebarSelector.cs`
- Modify: `plugins/codex-usage-sidebar/windows/src/CodexUsageSidebar.Windows/ValidatedUiaTitlebarScanner.cs`
- Test: `plugins/codex-usage-sidebar/windows/tests/CodexUsageSidebar.Windows.Tests/CodexTitlebarSelectorTests.cs`

**Interfaces:**
- Consumes: `CodexTitlebarSelector.TryResolve(...)` and the measured redacted UIA node contract.
- Produces: a `TitlebarSnapshot` for either the wrapped or flat exact title structure.

- [x] **Step 1: Add the measured fixture and failing positive/negative tests**
- [x] **Step 2: Run focused tests and observe selector failure**
- [x] **Step 3: Resolve exactly one wrapped or flat title triplet**
- [x] **Step 4: Run focused selector tests to green**

### Task 2: Known-build visible fallback

**Files:**
- Modify: `plugins/codex-usage-sidebar/windows/src/CodexUsageSidebar.Windows/WindowsHostCoordinator.cs`
- Test: `plugins/codex-usage-sidebar/windows/tests/CodexUsageSidebar.Windows.Tests/HostCoordinatorTests.cs`

**Interfaces:**
- Consumes: authenticated `HostWindowSnapshot` and a fresh `AllowanceSnapshot`.
- Produces: a `PlacementResult` centered in the known Codex host at measured toolbar height.

- [x] **Step 1: Add known-build positive and unknown-build rejection tests**
- [x] **Step 2: Run focused tests and observe fallback failure**
- [x] **Step 3: Add bounded physical-pixel fallback calculation**
- [x] **Step 4: Run focused coordinator tests to green**

### Task 3: Payload integration and real-device verification

**Files:**
- Modify: `scripts/WindowsDevicePayload.Source.psm1`
- Modify: `scripts/install-windows-device-payload.ps1`
- Modify: `scripts/build-windows-v030-setup.ps1`
- Modify: `tests/test-windows-device-payload.ps1`

**Interfaces:**
- Consumes: three pinned UIA fixtures for build `151.0.7922.76`.
- Produces: a nonpublishable x64 device-test installer and installed payload bound to the new source commit.

- [x] **Step 1: Extend selector manifest tests to require the flat fixture**
- [x] **Step 2: Update payload builders to include all three pinned fixtures**
- [x] **Step 3: Run full Windows tests, format, build, manifest, workflow, and v0.2.3 freeze gates**
- [ ] **Step 4: Commit, rebuild, and atomically install the current-user device-test payload**
- [ ] **Step 5: Verify sanitized UIA resolution and inspect screenshots of compact and hover detail states**

### Task 4: GitHub candidate publication

**Files:**
- Modify only evidence and release metadata permitted by the existing v0.3.0 candidate pipeline.

**Interfaces:**
- Consumes: verified source commit, complete real-device evidence, Windows x64 and macOS arm64 candidate workflows.
- Produces: pushed `v0.3.0` branch and GitHub candidate artifacts without overwriting v0.2.3.

- [ ] **Step 1: Confirm worktree scope, GitHub CLI authentication, and remote branch state**
- [ ] **Step 2: Complete the required real-device matrix and bind evidence**
- [ ] **Step 3: Build and verify Windows x64 and macOS arm64 candidates**
- [ ] **Step 4: Push `v0.3.0`, monitor CI, and publish only provenance-verified assets**
