# Tibo X Information Entry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a localized native Tibo X information entry above the quota rows, dismiss the popover before opening the exact profile URL, and install a locally verified macOS companion.

**Architecture:** `SidebarCore` owns the localized presentation model and deterministic layout. AppKit renders a dedicated link control, while a small activation coordinator guarantees dismissal-before-navigation and keeps `NSWorkspace` behind an injected closure.

**Tech Stack:** Swift 6, Foundation, AppKit, XCTest, Swift Package Manager, shell-based plugin validation and local LaunchAgent installation.

## Global Constraints

- The target URL is exactly `https://x.com/thsottiaux` and uses the system default browser.
- The popover dismisses and clears pinned state before the URL opener runs.
- Use concept C placement with concept A styling; no blue banner/card treatment.
- Support Simplified Chinese, Traditional Chinese, and English through the existing Codex language resolver.
- Keep the card width at 300 points, maximum height at 480 points, and product version at `0.3.0`.
- Add no network fetching, X authentication, telemetry, scraping, post analysis, or reset prediction.
- Preserve unrelated main-checkout changes and do not push to GitHub.

---

### Task 1: Localized information-entry presentation model

**Files:**
- Modify: `plugins/codex-usage-sidebar/native/Sources/SidebarCore/QuotaLocalization.swift`
- Modify: `plugins/codex-usage-sidebar/native/Sources/SidebarCore/QuotaDetailFormatter.swift`
- Modify: `plugins/codex-usage-sidebar/native/Tests/SidebarCoreTests/QuotaLocalizationTests.swift`
- Modify: `plugins/codex-usage-sidebar/native/Tests/SidebarCoreTests/QuotaDetailFormatterTests.swift`

**Interfaces:**
- Consumes: `CodexDisplayLanguage`, `QuotaLocalization`, and `QuotaDetailFormatter.content(snapshot:now:language:timeZone:)`.
- Produces: `QuotaInformationEntry`, `QuotaDetailContent.informationEntry`, `QuotaLocalization.tiboXTitle`, and `QuotaLocalization.tiboXAccessibilityLabel`.

- [ ] **Step 1: Write failing localization and formatter tests**

Add literal expectations for all languages:

```swift
XCTAssertEqual(
    QuotaLocalization(language: .simplifiedChinese).tiboXTitle,
    "Tibo 的 X 动态"
)
XCTAssertEqual(
    QuotaLocalization(language: .traditionalChinese).tiboXTitle,
    "Tibo 的 X 動態"
)
XCTAssertEqual(
    QuotaLocalization(language: .english).tiboXTitle,
    "Tibo on X"
)
```

Extend the existing formatter fixtures and assert the real formatted content:

```swift
XCTAssertEqual(content.informationEntry.title, "Tibo on X")
XCTAssertEqual(
    content.informationEntry.accessibilityLabel,
    "Open Tibo's X profile in the browser"
)
XCTAssertEqual(
    content.informationEntry.destination.absoluteString,
    "https://x.com/thsottiaux"
)
```

- [ ] **Step 2: Run focused tests and verify RED**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcrun swift test \
  --package-path plugins/codex-usage-sidebar/native \
  --filter 'Quota(Localization|DetailFormatter)Tests'
```

Expected: compilation fails because the Tibo localization properties and `informationEntry` do not exist.

- [ ] **Step 3: Add the minimal localized model and formatter output**

Add the model beside `QuotaDetailContent`:

```swift
public struct QuotaInformationEntry: Equatable, Sendable {
    public let title: String
    public let accessibilityLabel: String
    public let destination: URL
}

public struct QuotaDetailContent: Equatable, Sendable {
    public let title: String
    public let remainingPercent: Int
    public let informationEntry: QuotaInformationEntry
    public let rows: [QuotaDetailRow]
}
```

Add exact language switches in `QuotaLocalization`, then create the entry in `QuotaDetailFormatter` with:

```swift
private static let tiboProfileURL = URL(
    string: "https://x.com/thsottiaux"
)!

let informationEntry = QuotaInformationEntry(
    title: copy.tiboXTitle,
    accessibilityLabel: copy.tiboXAccessibilityLabel,
    destination: Self.tiboProfileURL
)
```

- [ ] **Step 4: Run focused tests and verify GREEN**

Run the Step 2 command. Expected: all localization and formatter tests pass with no warnings.

- [ ] **Step 5: Commit the presentation model**

```bash
git add plugins/codex-usage-sidebar/native/Sources/SidebarCore \
  plugins/codex-usage-sidebar/native/Tests/SidebarCoreTests
git commit -m "feat: add localized Tibo information entry"
```

### Task 2: Deterministic information-band layout

**Files:**
- Modify: `plugins/codex-usage-sidebar/native/Sources/SidebarCore/QuotaDetailLayout.swift`
- Modify: `plugins/codex-usage-sidebar/native/Tests/SidebarCoreTests/QuotaDetailLayoutTests.swift`

**Interfaces:**
- Consumes: a 300-point quota card bounds rectangle.
- Produces: `QuotaDetailInformationFrames`, `QuotaDetailLayout.informationFrames(in:)`, `QuotaDetailLayout.rowAreaFrame(in:)`, and the new 120-point `headerHeight`.

- [ ] **Step 1: Write failing layout tests**

Add exact, hand-derived frame expectations:

```swift
let bounds = CGRect(x: 0, y: 0, width: 300, height: 320)
let frames = QuotaDetailLayout.informationFrames(in: bounds)

XCTAssertEqual(frames.control, CGRect(x: 12, y: 214, width: 276, height: 32))
XCTAssertEqual(frames.topDivider.minY, 254)
XCTAssertEqual(frames.bottomDivider.minY, 206)
XCTAssertLessThan(frames.rowArea.maxY, frames.bottomDivider.minY)
XCTAssertEqual(frames.rowArea.maxY, 200)
```

Update the wrapped-row content-height expectation from `304` to `346`, and keep the maximum-height expectation at `480`.

- [ ] **Step 2: Run the layout suite and verify RED**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcrun swift test \
  --package-path plugins/codex-usage-sidebar/native \
  --filter QuotaDetailLayoutTests
```

Expected: compilation fails because the information-frame API does not exist.

- [ ] **Step 3: Implement the pure frame policy**

Add:

```swift
public struct QuotaDetailInformationFrames: Equatable, Sendable {
    public let topDivider: CGRect
    public let control: CGRect
    public let bottomDivider: CGRect
    public let rowArea: CGRect
}
```

Set `headerHeight = 120` and derive all frames from `bounds.maxY`:

```swift
public static func informationFrames(
    in bounds: CGRect
) -> QuotaDetailInformationFrames {
    QuotaDetailInformationFrames(
        topDivider: CGRect(x: 0, y: bounds.maxY - 66, width: bounds.width, height: 1),
        control: CGRect(x: 12, y: bounds.maxY - 106, width: bounds.width - 24, height: 32),
        bottomDivider: CGRect(x: 0, y: bounds.maxY - 114, width: bounds.width, height: 1),
        rowArea: rowAreaFrame(in: bounds)
    )
}

public static func rowAreaFrame(in bounds: CGRect) -> CGRect {
    CGRect(x: 0, y: 8, width: bounds.width, height: max(0, bounds.height - headerHeight - 8))
}
```

- [ ] **Step 4: Run layout tests and verify GREEN**

Run the Step 2 command. Expected: all layout tests pass.

- [ ] **Step 5: Commit the layout policy**

```bash
git add plugins/codex-usage-sidebar/native/Sources/SidebarCore/QuotaDetailLayout.swift \
  plugins/codex-usage-sidebar/native/Tests/SidebarCoreTests/QuotaDetailLayoutTests.swift
git commit -m "feat: reserve native Tibo information band"
```

### Task 3: Dismiss-before-open activation and native AppKit control

**Files:**
- Modify: `plugins/codex-usage-sidebar/native/Package.swift`
- Create: `plugins/codex-usage-sidebar/native/Sources/CodexUsageSidebar/QuotaExternalLinkActivator.swift`
- Create: `plugins/codex-usage-sidebar/native/Sources/CodexUsageSidebar/QuotaInformationLinkButton.swift`
- Modify: `plugins/codex-usage-sidebar/native/Sources/CodexUsageSidebar/QuotaDetailPanel.swift`
- Modify: `plugins/codex-usage-sidebar/native/Sources/CodexUsageSidebar/OverlayPanel.swift`
- Create: `plugins/codex-usage-sidebar/native/Tests/CodexUsageSidebarTests/QuotaExternalLinkActivatorTests.swift`

**Interfaces:**
- Consumes: `QuotaInformationEntry`, `QuotaDetailLayout.informationFrames(in:)`, and an injected `(URL) -> Bool` opener.
- Produces: `QuotaExternalLinkActivator.activate(_:)`, `QuotaInformationLinkButton`, and `QuotaDetailPanel.onOpenURL`.

- [ ] **Step 1: Add a failing activation-order test**

Add a `CodexUsageSidebarTests` test target depending on `CodexUsageSidebar`, then add:

```swift
@MainActor
func testDismissesBeforeOpeningTheExactDestination() {
    var events: [String] = []
    let activator = QuotaExternalLinkActivator(
        dismiss: { events.append("dismiss") },
        open: { url in
            events.append("open:\(url.absoluteString)")
            return true
        }
    )

    activator.activate(URL(string: "https://x.com/thsottiaux")!)

    XCTAssertEqual(
        events,
        ["dismiss", "open:https://x.com/thsottiaux"]
    )
}
```

- [ ] **Step 2: Run the new test and verify RED**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcrun swift test \
  --package-path plugins/codex-usage-sidebar/native \
  --filter QuotaExternalLinkActivatorTests
```

Expected: compilation fails because `QuotaExternalLinkActivator` does not exist.

- [ ] **Step 3: Implement the minimal activator and verify GREEN**

```swift
@MainActor
final class QuotaExternalLinkActivator {
    private let dismiss: () -> Void
    private let open: (URL) -> Bool

    init(dismiss: @escaping () -> Void, open: @escaping (URL) -> Bool) {
        self.dismiss = dismiss
        self.open = open
    }

    func activate(_ destination: URL) {
        dismiss()
        _ = open(destination)
    }
}
```

Run the Step 2 command. Expected: the activation-order test passes.

- [ ] **Step 4: Implement the native link control**

Create a borderless `NSButton` subclass that:

```swift
final class QuotaInformationLinkButton: NSButton {
    init(
        frame: NSRect,
        entry: QuotaInformationEntry,
        onActivate: @escaping (URL) -> Void
    )
}
```

The button uses a 24-point monochrome X icon, 12-point medium label, 12-point secondary `↗`, an eight-point rounded semantic hover surface, a stronger pressed alpha, a pointing-hand cursor, `NSAccessibility.Role.link`, and the localized accessibility label. It performs no navigation itself.

- [ ] **Step 5: Wire the card, panel, and overlay**

Use `QuotaDetailLayout.informationFrames(in:)` in `QuotaDetailCardView`, replace the hard-coded row area with `frames.rowArea`, and forward the button URL through `QuotaDetailPanel.onOpenURL`.

In `OverlayPanel`, configure one activator whose dismiss closure runs:

```swift
detailInteraction.reset()
isHoveringIndicator = false
detailPanel.hide()
updateControlAppearance()
```

and whose production opener is:

```swift
{ NSWorkspace.shared.open($0) }
```

- [ ] **Step 6: Run focused and full Swift tests**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcrun swift test \
  --package-path plugins/codex-usage-sidebar/native \
  --filter 'Quota(ExternalLinkActivator|DetailLayout|Localization|DetailFormatter)Tests'

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcrun swift test \
  --package-path plugins/codex-usage-sidebar/native
```

Expected: all focused tests and the complete package suite pass with zero failures.

- [ ] **Step 7: Commit the AppKit feature**

```bash
git add plugins/codex-usage-sidebar/native
git commit -m "feat: open Tibo profile from quota popover"
```

### Task 4: Build, install, and visually verify the local plugin

**Files:**
- Modify for local build only: `plugins/codex-usage-sidebar/.codex-plugin/plugin.json`
- Regenerate for local build only: `plugins/codex-usage-sidebar/assets/Codex Usage Sidebar.app/Contents/Info.plist`
- Regenerate for local build only: `plugins/codex-usage-sidebar/assets/Codex Usage Sidebar.app/Contents/MacOS/CodexUsageSidebar`

**Interfaces:**
- Consumes: the tested Swift source and the existing plugin build/control scripts.
- Produces: a signed, cache-busted, locally installed `0.3.0` companion and direct visual evidence in Codex.

- [ ] **Step 1: Update only the local Codex cachebuster**

```bash
python3 /Users/byctor/.codex/skills/.system/plugin-creator/scripts/update_plugin_cachebuster.py \
  plugins/codex-usage-sidebar
```

Verify the version still begins with `0.3.0+codex.` and contains exactly one `+` suffix.

- [ ] **Step 2: Build and validate the signed companion**

```bash
bash plugins/codex-usage-sidebar/scripts/build-companion.sh
bash plugins/codex-usage-sidebar/tests/test-sidebar-control.sh
bash plugins/codex-usage-sidebar/tests/test-signing-identity.sh
bash plugins/codex-usage-sidebar/tests/test-bundle-version.sh
python3 /Users/byctor/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py \
  plugins/codex-usage-sidebar
CUS_ALLOW_SOURCE_AHEAD=1 bash scripts/validate-public-repo.sh
```

Expected: build, lifecycle, signing, version, manifest, and repository validation all pass.

- [ ] **Step 3: Install the worktree payload without editing marketplace files**

The configured marketplace points at the separate main checkout, so use the supported control script directly for this isolated visual-validation build:

```bash
bash plugins/codex-usage-sidebar/scripts/sidebar-control.sh repair \
  --plugin-root "$PWD/plugins/codex-usage-sidebar"
bash plugins/codex-usage-sidebar/scripts/sidebar-control.sh status \
  --plugin-root "$PWD/plugins/codex-usage-sidebar"
```

Expected: the signed LaunchAgent is installed and running, `plugin-root.txt` identifies this worktree, and runtime diagnostics report a visible quota indicator.

- [ ] **Step 4: Perform real Codex visual and interaction QA**

Use the running Codex app and verify:

1. Dark theme resting entry: below progress and above rows, transparent background, no overlap.
2. Dark theme hover: subtle native hover surface and pointing-hand cursor.
3. Click: quota popover dismisses and the browser opens `https://x.com/thsottiaux`.
4. Pinned popover click: pinned state clears before navigation.
5. Light theme: semantic colors and contrast match the Codex popover.
6. Simplified Chinese, Traditional Chinese, and English copy follow the effective Codex language.
7. Long Bank data remains scrollable and the Tibo entry stays fixed above the row scroller.

- [ ] **Step 5: Run the completion audit**

Re-run the full Swift suite, `git diff --check`, plugin validation, runtime status, and inspect the final branch diff against every acceptance criterion in the design spec. Keep generated local payload changes uncommitted and do not push GitHub.
