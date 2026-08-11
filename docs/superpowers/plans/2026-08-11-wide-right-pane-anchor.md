# Wide Right-Pane Anchor Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep the quota control in the available center-titlebar slot when a wide right pane moves Open Location left of the whole-window midpoint.

**Architecture:** Preserve the existing accessibility scan and collision resolver. Broaden only the semantic Open Location candidate set and the structural right-pane width range, while retaining the full-width-surface rejection and static-title barrier.

**Tech Stack:** Swift 6, CoreGraphics, XCTest, AppKit Accessibility, Bash packaging scripts

## Global Constraints

- Preserve the v0.2.3 version and existing UI appearance.
- Preserve the 164-point indicator width and exact eight-point Open Location gap.
- Never place the control across an eligible static title barrier.
- Do not modify Codex application files or request new permissions.
- Publish only after focused, full-suite, package, and local-runtime verification.

---

### Task 1: Resolve wide-right-pane titlebar geometry

**Files:**
- Modify: `plugins/codex-usage-sidebar/native/Sources/SidebarCore/ContentHeaderAnchorResolver.swift:90-155,235-250`
- Test: `plugins/codex-usage-sidebar/native/Tests/SidebarCoreTests/ContentHeaderAnchorResolverTests.swift`

**Interfaces:**
- Consumes: `ContentHeaderAnchorResolver.resolve(controls:paneFrames:windowFrame:)`
- Produces: unchanged `ContentHeaderAnchor` API with `.openLocation` or `.rightPaneBoundary` for the reproduced wide-pane geometry

- [x] **Step 1: Write the failing semantic-anchor regression**

```swift
func testOpenLocationLeftOfWindowMidpointUsesVisibleFreeSlot() {
    let wideWindow = CGRect(x: 70, y: 0, width: 1_850, height: 1_049)
    let anchor = ContentHeaderAnchorResolver.resolve(
        controls: [
            control(x: 768, y: 1_012, width: 132, labels: ["打开位置"]),
            control(x: 910, y: 1_012, width: 28, labels: ["环境信息"]),
        ],
        paneFrames: [CGRect(x: 955, y: 0, width: 965, height: 1_049)],
        windowFrame: wideWindow
    )

    XCTAssertEqual(anchor, ContentHeaderAnchor(trailingEdge: 768, source: .openLocation))
    XCTAssertEqual(
        OverlayLayout.indicatorFrame(in: wideWindow, contentTrailingEdge: anchor.trailingEdge),
        CGRect(x: 596, y: 1_003, width: 164, height: 46)
    )
}
```

- [x] **Step 2: Run the semantic-anchor test and verify RED**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcrun swift test \
  --package-path plugins/codex-usage-sidebar/native \
  --filter ContentHeaderAnchorResolverTests/testOpenLocationLeftOfWindowMidpointUsesVisibleFreeSlot
```

Expected: FAIL because the current resolver returns `.fallback`.

- [x] **Step 3: Admit semantic Open Location candidates independently of midpoint**

Create a shared eligible anchor-candidate collection, use all of it for `isOpenLocation`, and keep the whole-window midpoint restriction only for generic labeled fallback controls. Do not change collision handling.

- [x] **Step 4: Run the semantic-anchor test and verify GREEN**

Run the Step 2 command again. Expected: one passing test.

- [x] **Step 5: Write the failing wide-pane-boundary regression**

```swift
func testRecognizesWideRightPaneBoundaryWithoutTreatingFullContentAsPane() {
    let wideWindow = CGRect(x: 70, y: 0, width: 1_850, height: 1_049)
    let anchor = ContentHeaderAnchorResolver.resolve(
        controls: [],
        paneFrames: [CGRect(x: 955, y: 0, width: 965, height: 1_049)],
        windowFrame: wideWindow
    )

    XCTAssertEqual(anchor, ContentHeaderAnchor(trailingEdge: 955, source: .rightPaneBoundary))
}
```

- [x] **Step 6: Run the pane-boundary test and verify RED**

Run the focused test by name. Expected: FAIL because the current structural pane ceiling is 520 points.

- [x] **Step 7: Replace the absolute pane ceiling with a proportional full-surface guard**

Accept right-anchored panes up to 60 percent of the window width. Keep the existing minimum width, height, right-edge, top/bottom, and toolbar-band checks so simultaneous outer content surfaces and the 82-percent full content fixture remain rejected while the reproduced 965/1850 pane still qualifies.

- [x] **Step 8: Run focused and full Swift suites**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcrun swift test --package-path plugins/codex-usage-sidebar/native \
  --filter ContentHeaderAnchorResolverTests

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcrun swift test --package-path plugins/codex-usage-sidebar/native
```

Expected: all tests pass with zero failures.

- [x] **Step 9: Build, install, and inspect the local companion**

Use the repository build/control scripts, preserve v0.2.3, and verify the installed runtime reports `anchor=openLocation` or `anchor=rightPaneBoundary` rather than `anchor=fallback` in the reproduced layout.

- [x] **Step 10: Validate and package**

```bash
git diff --check
CUS_ALLOW_SOURCE_AHEAD=1 bash scripts/validate-public-repo.sh
bash tests/test-installer-package.sh
```

Expected: all commands exit zero; the DMG remains named `codex-usage-sidebar-v0.2.3-macos-arm64.dmg`.

## Discovered scanner constraint (review follow-up)

The resolver may now select a semantic Open Location anchor left of the whole-window midpoint.
The locator must therefore not rely on one fixed horizontal descendant bound: a static-title branch
whose right edge is just left of that bound can overlap the resulting 164-point indicator without
ever reaching collision resolution. Keep the initial narrow scan, then rescan only as far left as
the resolved indicator frame requires. Repeat after a collision shift, retain the vertical/depth/
element guards, and stop after numeric fallback, a covered range, or a bounded number of passes.

Regression coverage must exercise scan filtering plus resolution for a free wide layout, a hidden
static-title barrier, a second expansion after a button collision, and termination.

- [ ] **Step 11: Commit and publish**

Stage only the resolver, tests, design, plan, rebuilt companion payload/provenance, and any required release documentation. Commit, push `codex/fix-wide-right-pane-placement`, open a ready PR to `main`, wait for CI, and merge only after review and checks pass.
