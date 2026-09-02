# Indicator Position Modes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add persistent Automatic, Free, and Locked placement modes to the macOS
title-bar quota indicator, exposed through the approved concept-C right-click
settings panel.

**Architecture:** Keep placement rules deterministic and testable in `SidebarCore`.
Persist only platform-specific screen identities and preferences in the AppKit
executable target. `RuntimeCoordinator` resolves either the existing automatic
frame or a saved manual frame; `OverlayPanel` owns pointer gesture routing and
the native position-mode popover.

**Tech Stack:** Swift 6, AppKit, CoreGraphics, XCTest, existing native macOS
companion build/reinstall scripts.

**Spec:** `docs/superpowers/specs/2026-08-30-indicator-position-modes-design.md`

## Global Constraints

- Preserve existing Automatic placement and its dynamic content-header fallback.
- Use test-driven development: run each new test failing before implementation,
  then rerun it passing after the smallest implementation.
- Use the approved C visual direction: native segmented control, no web styling.
- Keep Windows unchanged and do not publish or tag a release in this task.
- Treat this user-visible macOS feature as the next MINOR candidate (`0.4.0`)
  according to `docs/PROJECT_GOVERNANCE.md`; only update product version after
  functional validation succeeds.

## Tasks

### 1. Add pure placement domain model and tests

- [ ] Create `SidebarCore/IndicatorPlacement.swift` with:
  `IndicatorPlacementMode`, normalized manual placement, preferences, clamping,
  and automatic/manual resolution helpers.
- [ ] Create `SidebarCoreTests/IndicatorPlacementTests.swift` first. Cover:
  default automatic mode, normalized persistence across resized visible frames,
  clamping at every screen edge, transition capture, and distinct display keys.
- [ ] Run the focused tests to demonstrate they fail before implementation, then
  pass after the model is added.

### 2. Add localized mode copy and AppKit preferences store

- [ ] Add localized labels/descriptions and accessibility copy to
  `QuotaLocalization` with Chinese, Traditional Chinese, and English tests.
- [ ] Add `IndicatorPlacementStore.swift` in `CodexUsageSidebar`, backed by
  `UserDefaults` and a versioned Codable payload. Resolve a stable display
  identifier and retrieve the relevant screen from an indicator frame.
- [ ] Add executable-target tests for persistence encode/decode and default
  migration behaviour.

### 3. Add interaction routing and approved C settings popover

- [ ] Replace the panel-wide click recognizer with a small indicator interaction
  view so primary click, right click, and drag threshold are deterministic.
- [ ] Add a focused gesture-state test: Free drags after 4pt and suppresses the
  click; Automatic/Locked do not drag; ordinary primary clicks still invoke the
  quota-card action.
- [ ] Create `IndicatorPositionModePopover.swift` using a native AppKit
  `NSSegmentedControl`, localized heading and mode description. Add an AppKit
  control test for selected state, labels, and action callback.
- [ ] Wire a right click to show the panel and ensure it does not toggle the
  quota detail card.

### 4. Integrate with RuntimeCoordinator

- [ ] Add placement store/state to `RuntimeCoordinator`.
- [ ] Keep computing the automatic frame on every tick, then resolve the
  displayed frame from the selected mode and the active display.
- [ ] On transition to Free/Locked capture the visible automatic/current frame;
  on Free drag persist the updated normalized frame; on Automatic immediately
  return to the existing anchor frame.
- [ ] Ensure detail card anchoring, diagnostics, settings-page hiding, and
  visibility state continue to use the resolved displayed frame.
- [ ] Add regression tests for mode transitions and fallback-width layout.

### 5. Visual and behavioural verification

- [ ] Extend the native visual fixture coverage for light/dark selected mode
  states and inspect the rendered images against the approved C direction.
- [ ] Run full Swift tests, `git diff --check`, plugin validator, and public
  repository validator.
- [ ] Rebuild and repair-install the local companion; verify right-click,
  automatic resizing, Free drag, Locked drag rejection, persistence, and
  settings-page hiding in the running app.

### 6. Version and documentation candidate preparation

- [ ] Update `CHANGELOG.md` under Unreleased and macOS documentation to explain
  the three modes and per-display persistence.
- [ ] Once all functional checks pass, promote the macOS candidate metadata to
  `0.4.0`, update cachebuster/build metadata, and verify the badge and
  application metadata match. Do not create a tag, release, or GitHub push.
- [ ] Record evidence and next action on the local project board.

## Review checklist

- [ ] Automatic mode remains the default after clean install.
- [ ] No drag can accidentally happen on normal quota-card clicks.
- [ ] Manual frames never render partly behind the Dock or outside a display.
- [ ] The contextual panel is localized and usable in light and dark themes.
- [ ] No user-owned files or Windows paths are changed unintentionally.
