# Always-Visible Titlebar Usage Control Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep the Codex usage control in the right titlebar on every confirmed main surface, independent of left-sidebar state.

**Architecture:** Preserve accessibility scanning as conservative main/non-main surface classification, but normalize every renderable placement to `.titlebar`. Make the state model reject footer placement so skipped or temporarily unavailable probes cannot restore an old persisted sidebar value.

**Tech Stack:** Swift 6, AppKit, XCTest, Bash lifecycle scripts, Codex plugin marketplace metadata, GitHub Actions.

## Global Constraints

- Settings and other completed non-main surfaces must still hide the control.
- Hover details, theme adaptation, live quota refresh, Bank rows, and stale-data handling must not change.
- The signed Codex application bundle remains read-only.
- The marketplace binary must be promoted from the exact successful CI artifact and recorded in `assets/PROVENANCE.json`.

---

### Task 1: Lock permanent titlebar behavior with failing tests

**Files:**
- Modify: `plugins/codex-usage-sidebar/native/Tests/SidebarCoreTests/OverlayPresentationPolicyTests.swift`
- Modify: `plugins/codex-usage-sidebar/native/Tests/SidebarCoreTests/SidebarVisibilityStateTests.swift`
- Modify: `plugins/codex-usage-sidebar/native/Sources/SidebarCore/OverlayPresentationPolicy.swift`
- Modify: `plugins/codex-usage-sidebar/native/Sources/SidebarCore/SidebarVisibilityState.swift`

**Interfaces:**
- Consumes: `SidebarChromeProbe.resolved(OverlayPlacement)` and `SidebarVisibilityState`.
- Produces: every confirmed main probe returns `.show(.titlebar)`; state initialization, toggles, and observed sidebar values retain `.titlebar`.

- [ ] **Step 1: Change the policy test to require titlebar for both observed sidebar states**

```swift
func testResolvedMainSurfaceAlwaysShowsInTitlebar() {
    XCTAssertEqual(
        OverlayPresentationPolicy.decision(for: .resolved(.sidebar)),
        .show(.titlebar)
    )
    XCTAssertEqual(
        OverlayPresentationPolicy.decision(for: .resolved(.titlebar)),
        .show(.titlebar)
    )
}
```

- [ ] **Step 2: Change state tests to require titlebar normalization**

```swift
func testPlacementAlwaysRemainsTitlebar() {
    var state = SidebarVisibilityState(hostIdentity: "a", placement: .sidebar)
    XCTAssertEqual(state.placement, .titlebar)
    state.toggle()
    XCTAssertEqual(state.placement, .titlebar)
    XCTAssertFalse(state.observePlacement(.sidebar))
    XCTAssertEqual(state.placement, .titlebar)
}
```

- [ ] **Step 3: Run focused tests and verify RED**

Run:

```bash
xcrun swift test \
  --package-path plugins/codex-usage-sidebar/native \
  --filter 'OverlayPresentationPolicyTests|SidebarVisibilityStateTests'
```

Expected: failures showing `.show(.sidebar)` and `.sidebar` where `.titlebar` is required.

- [ ] **Step 4: Normalize resolved probes and state to titlebar**

In `OverlayPresentationPolicy.decision`, ignore the associated resolved placement and return
`.show(.titlebar)`. In `SidebarVisibilityState`, normalize the initializer to `.titlebar`; make
`toggle()` retain `.titlebar`; make `observePlacement` return `false` without accepting `.sidebar`.

- [ ] **Step 5: Run focused and full Swift tests**

Run the focused command above, then:

```bash
xcrun swift test --package-path plugins/codex-usage-sidebar/native
```

Expected: all tests pass with no failures.

- [ ] **Step 6: Commit the behavior and regression tests**

```bash
git add plugins/codex-usage-sidebar/native/Sources/SidebarCore \
  plugins/codex-usage-sidebar/native/Tests/SidebarCoreTests
git commit -m "fix: keep usage control in titlebar"
```

### Task 2: Update public behavior documentation and patch version

**Files:**
- Modify: `README.md`
- Modify: `README.zh-CN.md`
- Modify: `CHANGELOG.md`
- Modify: `docs/images/placement.svg`
- Create: `docs/releases/v0.1.1.md`
- Modify: `plugins/codex-usage-sidebar/.codex-plugin/plugin.json`
- Modify: `plugins/codex-usage-sidebar/README.md`
- Modify: `.github/workflows/ci.yml`
- Modify: `scripts/validate-public-repo.sh`

**Interfaces:**
- Consumes: fixed titlebar behavior from Task 1.
- Produces: version `0.1.1`, accurate screenshots/copy, and branch CI that may build source ahead of the last promoted binary while main still requires exact provenance.

- [ ] **Step 1: Update README behavior tables and placement SVG**

Describe both expanded and collapsed sidebar states as using the right titlebar. Redraw the expanded
panel in `placement.svg` with the same titlebar control position and no footer quota control.

- [ ] **Step 2: Add v0.1.1 changelog and release notes**

State that footer placement was removed to eliminate anchor failures and that Settings hiding is
unchanged.

- [ ] **Step 3: Bump the plugin version**

Set `.codex-plugin/plugin.json` to `0.1.1+codex.20260802035130` and update the nested plugin
README if it names the old placement behavior.

- [ ] **Step 4: Permit provenance source-ahead validation only outside main**

Add a `CUS_ALLOW_SOURCE_AHEAD=1` validator mode that still validates the currently shipped binary
hash and signature but skips only the source-tree equality check. In CI, enable it for non-main refs;
main keeps the default strict provenance check.

- [ ] **Step 5: Validate docs, JSON, SVG, YAML, and repository privacy**

```bash
CUS_ALLOW_SOURCE_AHEAD=1 bash scripts/validate-public-repo.sh
ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci.yml")'
git diff --check
```

Expected: every command exits 0.

- [ ] **Step 6: Commit documentation and release metadata**

```bash
git add README.md README.zh-CN.md CHANGELOG.md docs plugins .github scripts
git commit -m "docs: prepare v0.1.1 titlebar release"
```

### Task 3: Build, install, and verify the repaired companion

**Files:**
- Rebuild: `plugins/codex-usage-sidebar/assets/Codex Usage Sidebar.app`
- Verify: `plugins/codex-usage-sidebar/tests/test-sidebar-control.sh`
- Verify: `plugins/codex-usage-sidebar/tests/live-app-server-probe.sh`

**Interfaces:**
- Consumes: versioned source from Tasks 1-2.
- Produces: a locally signed companion installed through the normal control script.

- [ ] **Step 1: Build from source**

```bash
bash plugins/codex-usage-sidebar/scripts/build-companion.sh
```

Expected: 89 or more Swift tests pass and the arm64 app signature verifies.

- [ ] **Step 2: Run lifecycle and live quota probes**

```bash
bash plugins/codex-usage-sidebar/tests/test-sidebar-control.sh
bash plugins/codex-usage-sidebar/tests/live-app-server-probe.sh
```

Expected: lifecycle PASS and a live `remaining=... reset_epoch=...` line.

- [ ] **Step 3: Install the rebuilt companion**

```bash
bash plugins/codex-usage-sidebar/scripts/sidebar-control.sh repair \
  --plugin-root "$PWD/plugins/codex-usage-sidebar" \
  --plugin-data "$HOME/Library/Application Support/CodexUsageSidebar/Data"
```

Expected: diagnostic reports `placement=titlebar` and `installed and loaded`.

- [ ] **Step 4: Visually verify both sidebar states and Settings**

Capture the Codex window with the sidebar expanded and collapsed. Confirm the control remains before
the right-side native icon group in both states and disappears on Settings.

### Task 4: Promote CI artifact and publish v0.1.1

**Files:**
- Replace: `plugins/codex-usage-sidebar/assets/Codex Usage Sidebar.app`
- Modify: `plugins/codex-usage-sidebar/assets/PROVENANCE.json`

**Interfaces:**
- Consumes: successful branch CI artifact from the exact source commit.
- Produces: marketplace snapshot and release assets containing the identical tested executable.

- [ ] **Step 1: Push the feature branch and wait for green CI**

```bash
git push -u origin codex/always-titlebar
run_id="$(gh run list --repo Byctor/codex-usage-sidebar --branch codex/always-titlebar \
  --limit 1 --json databaseId --jq '.[0].databaseId')"
gh run watch "$run_id" --repo Byctor/codex-usage-sidebar --exit-status
```

- [ ] **Step 2: Download and verify the CI artifact**

Verify its `SHA256SUMS.txt`, unzip it, verify the app signature, and record the Actions artifact
digest, archive SHA-256, executable SHA-256, and full CDHash.

- [ ] **Step 3: Promote the exact app and update provenance**

Replace only the marketplace app with the CI copy and update `PROVENANCE.json` to bind it to the
source commit and workflow run. Run the strict validator without source-ahead mode.

- [ ] **Step 4: Commit, merge to main, and wait for strict main CI**

```bash
git commit -m "release: promote v0.1.1 CI companion"
git switch main
git merge --ff-only codex/always-titlebar
git push origin main
```

Expected: main CI passes shipped-provenance validation, full build/tests, packaging, and artifact
upload.

- [ ] **Step 5: Publish and verify v0.1.1**

Create the GitHub Release with the provenance-bound CI ZIP and checksum, then perform a clean
isolated marketplace install from `Byctor/codex-usage-sidebar`. Verify installed version, signature,
and executable hash against `PROVENANCE.json`.
