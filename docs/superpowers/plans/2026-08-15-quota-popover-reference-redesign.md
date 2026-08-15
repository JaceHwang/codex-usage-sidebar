# Quota Popover Reference Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the native quota popover around the approved reference image while omitting the Jace/question footer and preserving live data and existing placement behavior.

**Architecture:** Keep `QuotaDetailFormatter` and the app-server streams as the source of truth, add a fixed seven-slot token display series, and separate card material, iconography, header, chart, and detail-row rendering into focused AppKit views. `QuotaDetailLayout` remains the single geometry authority so the wider card continues to clamp safely beside the existing indicator.

**Tech Stack:** Swift 6, Swift Package Manager, macOS 14 AppKit, XCTest, existing Codex app-server stdio transport, semantic AppKit colors and current `QuotaColorScale`.

## Global Constraints

- Use the supplied reference image as the single visual source of truth; do not render a Jace footer or question-mark/help button.
- Keep `account/rateLimits/read` and `account/usage/read` as the only live quota/token data paths.
- Keep product version `0.3.0`; update only the local cachebuster through the build script.
- Preserve Tibo URL `https://x.com/thsottiaux` and dismiss-before-open ordering.
- Preserve settings-page hiding, content-header/sidebar placement, hover/pin behavior, and app-server lifecycle handling.
- Preserve Simplified Chinese, Traditional Chinese, and English fallback.
- Always render seven token chart slots; future active-cycle dates are zero/empty and never fabricated.
- Use semantic Aqua/Dark Aqua colors; do not cache appearance-specific colors outside the active drawing appearance.
- Keep Bank details scrollable below the fixed Tibo/token regions and do not let scrolling overlap them.
- Preserve the three pre-existing generated build artifacts as build outputs; do not hand-edit them or push GitHub.

---

### Task 1: Add the seven-slot token display series

**Files:**
- Modify: `plugins/codex-usage-sidebar/native/Sources/SidebarCore/TokenUsageWindow.swift`
- Modify: `plugins/codex-usage-sidebar/native/Sources/SidebarCore/QuotaDetailFormatter.swift`
- Modify: `plugins/codex-usage-sidebar/native/Tests/SidebarCoreTests/TokenUsageWindowTests.swift`
- Modify: `plugins/codex-usage-sidebar/native/Tests/SidebarCoreTests/QuotaDetailFormatterTests.swift`

**Interfaces:**
- Add `TokenUsageWindow.referenceDays(from:allowance:now:timeZone:) -> [TokenUsageDay]`, returning exactly seven calendar-normalized days from the current cycle start, zero-filling missing and future days.
- Keep `TokenUsageWindow.currentCycle` unchanged for period totals and elapsed-day calculations.
- Have `QuotaDetailFormatter.displayTokenUsage` use the seven-slot series for `QuotaTokenUsagePresentation.days` while retaining the current-cycle total.

- [ ] **Step 1: Write failing seven-slot tests**

```swift
func testReferenceDaysAlwaysContainSevenSlotsAndZeroFillFutureDates() {
    let days = TokenUsageWindow.referenceDays(
        from: snapshot(buckets: [bucket("2026-08-13", 1200)]),
        allowance: allowance(resetsAt: date("2026-08-20 19:31"), windowMinutes: 10080),
        now: date("2026-08-15 20:00"),
        timeZone: shanghai
    )
    XCTAssertEqual(days.count, 7)
    XCTAssertEqual(days.map(\.tokens), [1200, 0, 0, 0, 0, 0, 0])
}
```

- [ ] **Step 2: Run the focused test and verify failure**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcrun swift test --package-path plugins/codex-usage-sidebar/native \
  --filter TokenUsageWindowTests --filter QuotaDetailFormatterTests
```

Expected: FAIL because `referenceDays` does not exist and formatter output still uses elapsed days only.

- [ ] **Step 3: Implement the fixed display series**

Derive the seven start-of-day dates from the cycle period start. Clamp the series to the first seven cycle dates, map available buckets, and insert zero tokens for missing or future dates. Keep `totalTokens` sourced from the elapsed current-cycle calculation so future zeros cannot alter the total. Return a safe zero series when token data is unavailable.

- [ ] **Step 4: Run focused and formatter tests**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcrun swift test --package-path plugins/codex-usage-sidebar/native \
  --filter TokenUsageWindowTests --filter QuotaDetailFormatterTests
```

Expected: PASS, including existing reset, Bank, and localization assertions.

- [ ] **Step 5: Commit the data-presentation change**

```bash
git add plugins/codex-usage-sidebar/native/Sources/SidebarCore/TokenUsageWindow.swift \
  plugins/codex-usage-sidebar/native/Sources/SidebarCore/QuotaDetailFormatter.swift \
  plugins/codex-usage-sidebar/native/Tests/SidebarCoreTests/TokenUsageWindowTests.swift \
  plugins/codex-usage-sidebar/native/Tests/SidebarCoreTests/QuotaDetailFormatterTests.swift
git commit -m "feat: normalize seven-slot token chart data"
```

### Task 2: Rebuild the reference card geometry and material

**Files:**
- Modify: `plugins/codex-usage-sidebar/native/Sources/SidebarCore/QuotaDetailLayout.swift`
- Modify: `plugins/codex-usage-sidebar/native/Sources/CodexUsageSidebar/QuotaDetailPanel.swift`
- Create: `plugins/codex-usage-sidebar/native/Sources/CodexUsageSidebar/QuotaCardMaterialView.swift`
- Modify: `plugins/codex-usage-sidebar/native/Tests/SidebarCoreTests/QuotaDetailLayoutTests.swift`
- Modify: `plugins/codex-usage-sidebar/native/Tests/CodexUsageSidebarTests/QuotaDetailCardVisualTests.swift`

**Interfaces:**
- Set a wide reference geometry (`width` approximately 520 points, `maximumHeight` approximately 720 points) while clamping against `visibleFrame`.
- Add `QuotaCardMaterialView` as the card's background layer, resolving material, border, and shadow colors during drawing.
- Keep `QuotaDetailLayout.informationFrames(in:tokenUsageVisible:)` as the only source for header, Tibo row, token band, and scroll-area frames.

- [ ] **Step 1: Write failing geometry tests**

Assert the wider card stays inside the visible screen, the header/progress/Tibo/token/detail regions have the reference order, and the seven-slot token band has enough width for seven columns without a horizontal scroller.

- [ ] **Step 2: Run layout tests and verify failure**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcrun swift test --package-path plugins/codex-usage-sidebar/native \
  --filter QuotaDetailLayoutTests
```

Expected: FAIL against the current compact 300-point geometry.

- [ ] **Step 3: Implement layout and material**

Move the card background from a flat `windowBackgroundColor` layer to `QuotaCardMaterialView`, use the approved continuous corner radius and thin border, and keep the panel's nonactivating/pop-up behavior unchanged. Increase header/progress/Tibo/token/detail spacing together so the card does not merely stretch empty regions.

- [ ] **Step 4: Render a first visual fixture**

Run the existing visual fixture with `CUS_VISUAL_OUTPUT_DIR` and inspect one Dark Aqua and one Aqua image before proceeding to detail-row work. The fixture must show no Jace/question footer.

- [ ] **Step 5: Commit the geometry/material change**

```bash
git add plugins/codex-usage-sidebar/native/Sources/SidebarCore/QuotaDetailLayout.swift \
  plugins/codex-usage-sidebar/native/Sources/CodexUsageSidebar/QuotaDetailPanel.swift \
  plugins/codex-usage-sidebar/native/Sources/CodexUsageSidebar/QuotaCardMaterialView.swift \
  plugins/codex-usage-sidebar/native/Tests/SidebarCoreTests/QuotaDetailLayoutTests.swift \
  plugins/codex-usage-sidebar/native/Tests/CodexUsageSidebarTests/QuotaDetailCardVisualTests.swift
git commit -m "feat: match quota popover reference geometry"
```

### Task 3: Match header, Tibo row, token chart, and detail rows

**Files:**
- Modify: `plugins/codex-usage-sidebar/native/Sources/CodexUsageSidebar/QuotaDetailPanel.swift`
- Modify: `plugins/codex-usage-sidebar/native/Sources/CodexUsageSidebar/QuotaTokenUsageView.swift`
- Create: `plugins/codex-usage-sidebar/native/Sources/CodexUsageSidebar/QuotaDetailIconView.swift`
- Modify: `plugins/codex-usage-sidebar/native/Tests/CodexUsageSidebarTests/QuotaDetailCardVisualTests.swift`
- Modify: `plugins/codex-usage-sidebar/native/Tests/SidebarCoreTests/QuotaCountdownSegmentsTests.swift`

**Interfaces:**
- `QuotaDetailIconView(kind: QuotaDetailIconKind)` draws the linear plan/calendar/clock/credits/Bank/refresh icons with semantic colors.
- `QuotaTokenUsageView` renders exactly seven columns, the “每日”/legend hierarchy, current-day accent, and delay note without a horizontal scroller.
- `QuotaDetailCardView` renders the larger title, avatar/neutral fallback, version capsule, remaining percentage, outlined Tibo row, icon-led detail rows, and a clean bottom inset; it must not add Jace/question controls.

- [ ] **Step 1: Add failing visual/typography assertions**

Extend the fixture test to assert seven bar subviews, no horizontal scroller, the outlined Tibo row, the icon count matching detail rows, the absence of footer controls, and the emphasized reset day/hour segments.

- [ ] **Step 2: Run focused visual tests and verify failure**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcrun swift test --package-path plugins/codex-usage-sidebar/native \
  --filter QuotaDetailCardVisualTests --filter QuotaCountdownSegmentsTests
```

Expected: FAIL because the current card uses compact labels, no detail icons, and a variable-length chart.

- [ ] **Step 3: Implement the native reference hierarchy**

Use the existing semantic label colors and `QuotaColorScale`; resolve the avatar from a packaged stable asset only if present, otherwise render a neutral circular placeholder. Increase title/percentage typography, place the version capsule on the title baseline, draw the outlined Tibo row, add row icons and separators, and remove any footer controls. Make reset countdown digits visibly larger without changing Bank expiry segmentation.

- [ ] **Step 4: Render all visual states**

```bash
fixture_dir=$(mktemp -d /tmp/codex-quota-reference.XXXXXX)
CUS_VISUAL_OUTPUT_DIR="$fixture_dir" \
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcrun swift test --package-path plugins/codex-usage-sidebar/native \
  --filter QuotaDetailCardVisualTests
```

Inspect Simplified Chinese, Traditional Chinese, and English in Aqua/Dark Aqua. Confirm no overlap, seven columns, no footer, readable long Bank rows, and the reference-like hierarchy.

- [ ] **Step 5: Commit the native reference UI**

```bash
git add plugins/codex-usage-sidebar/native/Sources/CodexUsageSidebar/QuotaDetailPanel.swift \
  plugins/codex-usage-sidebar/native/Sources/CodexUsageSidebar/QuotaTokenUsageView.swift \
  plugins/codex-usage-sidebar/native/Sources/CodexUsageSidebar/QuotaDetailIconView.swift \
  plugins/codex-usage-sidebar/native/Tests/CodexUsageSidebarTests/QuotaDetailCardVisualTests.swift \
  plugins/codex-usage-sidebar/native/Tests/SidebarCoreTests/QuotaCountdownSegmentsTests.swift
git commit -m "feat: restyle quota popover to reference UI"
```

### Task 4: Full regression, rebuild, and local acceptance

**Files:**
- Modify through build scripts only: `plugins/codex-usage-sidebar/.codex-plugin/plugin.json`, `plugins/codex-usage-sidebar/assets/Codex Usage Sidebar.app/Contents/Info.plist`, and the bundled companion binary.
- Do not hand-edit generated files.

- [ ] **Step 1: Run the full Swift suite**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcrun swift test --package-path plugins/codex-usage-sidebar/native
```

Expected: all existing and new tests pass.

- [ ] **Step 2: Run validators and live probes**

```bash
bash plugins/codex-usage-sidebar/tests/test-sidebar-control.sh
bash plugins/codex-usage-sidebar/tests/test-signing-identity.sh
bash plugins/codex-usage-sidebar/tests/test-bundle-version.sh
bash plugins/codex-usage-sidebar/tests/live-app-server-probe.sh
plugin_creator_skill="${CODEX_HOME:-${HOME}/.codex}/skills/.system/plugin-creator"
uv run --with PyYAML python "$plugin_creator_skill/scripts/validate_plugin.py" plugins/codex-usage-sidebar
CUS_REBUILT_PAYLOAD=1 bash scripts/validate-public-repo.sh
git diff --check
```

- [ ] **Step 3: Rebuild and reinstall the local payload**

```bash
plugin_creator_skill="${CODEX_HOME:-${HOME}/.codex}/skills/.system/plugin-creator"
python3 "$plugin_creator_skill/scripts/update_plugin_cachebuster.py" plugins/codex-usage-sidebar
bash plugins/codex-usage-sidebar/scripts/build-companion.sh
bash plugins/codex-usage-sidebar/scripts/sidebar-control.sh repair \
  --plugin-root "$PWD/plugins/codex-usage-sidebar"
```

- [ ] **Step 4: Verify real Codex behavior**

Capture Dark Aqua and Aqua runtime screenshots. Verify the content-header indicator and popover placement, settings hiding, Tibo exact URL, seven chart slots with zero future values, scrolling Bank rows, language fallback, and no Jace/question footer.

- [ ] **Step 5: Record the final board checkpoint**

```bash
board_script="${CODEX_HOME:-${HOME}/.codex}/skills/tracking-project-progress/scripts/project_board.py"
python3 "$board_script" validate --project-root "$PWD"
```

Record the final verification commands and leave the branch local; do not push GitHub.
