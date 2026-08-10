# Emphasized Countdown Typography Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render the numeric portions of compact reset intervals as larger, semibold, quota-colored text in both Codex themes while keeping units and parentheses visually subordinate.

**Architecture:** `SidebarCore` owns deterministic compact-duration segmentation. The AppKit popover consumes those semantic segments to build and measure one attributed string, keeping parsing testable and rendering aligned.

**Tech Stack:** Swift 6, Foundation, AppKit, XCTest, shell-based plugin validation and installation.

## Global Constraints

- Preserve the existing 300-point card width and one-line reset/Bank date rows.
- Do not add capsules, backgrounds, borders, underlines, or shadows around intervals.
- Use the existing `QuotaColorScale` accent for digits.
- Use AppKit semantic colors for units and punctuation in light and dark themes.
- Preserve Simplified Chinese, Traditional Chinese, and English output.

---

### Task 1: Compact-Duration Segmentation

**Files:**
- Create: `plugins/codex-usage-sidebar/native/Sources/SidebarCore/QuotaCountdownSegments.swift`
- Create: `plugins/codex-usage-sidebar/native/Tests/SidebarCoreTests/QuotaCountdownSegmentsTests.swift`

**Interfaces:**
- Produces: `QuotaCountdownSegmenter.segments(in:) -> [QuotaCountdownSegment]`.
- Produces: segment roles `.plain`, `.punctuation`, `.digits`, `.unit`, and `.suffix`.

- [ ] **Step 1: Write failing tests** for CJK full-width parentheses, English ASCII parentheses, past suffixes, Bank status suffixes, and plain values.
- [ ] **Step 2: Run** `swift test --filter QuotaCountdownSegmentsTests` and confirm the missing API causes the expected failure.
- [ ] **Step 3: Implement** a strict parser for the final compact interval without changing visible text.
- [ ] **Step 4: Re-run** the focused tests and confirm they pass.

### Task 2: Theme-Aware Attributed Row Values

**Files:**
- Modify: `plugins/codex-usage-sidebar/native/Sources/CodexUsageSidebar/QuotaDetailPanel.swift`
- Modify: `plugins/codex-usage-sidebar/native/Sources/SidebarCore/QuotaDetailLayout.swift` only if attributed measurement proves the existing width unsafe.
- Test: `plugins/codex-usage-sidebar/native/Tests/SidebarCoreTests/QuotaDetailLayoutTests.swift`

**Interfaces:**
- Consumes: `QuotaCountdownSegmenter.segments(in:)`.
- Produces: one `NSAttributedString` per emphasized reset or Bank expiry value.

- [ ] **Step 1: Add or extend a layout regression** only if the emphasized attributed width exposes a real clipping boundary.
- [ ] **Step 2: Build attributed row values** with 14 pt semibold digits, 10 pt muted units and punctuation, and the existing 12 pt base value.
- [ ] **Step 3: Measure and render from the same attributed string** so the row-height decision matches the visible result.
- [ ] **Step 4: Run focused and full Swift tests.**

### Task 3: Package, Theme Verification, and Publication

**Files:**
- Modify: `plugins/codex-usage-sidebar/.codex-plugin/plugin.json`
- Modify: `CHANGELOG.md`
- Create: `docs/releases/v0.2.2.md`
- Modify generated companion payload and provenance only through the repository's supported build/promotion flow.

**Interfaces:**
- Produces: a locally installed, version-synchronized v0.2.2 plugin and a GitHub branch/PR containing the verified source update.

- [ ] **Step 1: Bump the patch version to v0.2.2** and document the typography change.
- [ ] **Step 2: Build and install through the plugin update workflow.**
- [ ] **Step 3: Verify dark and light Codex appearances visually** with the live companion.
- [ ] **Step 4: Run plugin validation, repository validation, shell tests, Swift tests, and `git diff --check`.**
- [ ] **Step 5: Commit scoped files, push the branch, open a ready PR, merge after CI passes, and confirm `main` CI.**
