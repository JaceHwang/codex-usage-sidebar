# Token Usage Popover Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an official app-server-backed current-cycle token usage chart and total to the native quota popover while preserving the Tibo X row, multilingual behavior, countdown emphasis, and existing placement/lifecycle behavior.

**Architecture:** Keep rate-limit and token-usage snapshots as separate `SidebarCore` values. `AppServerClient` requests `account/usage/read` over the existing authenticated stdio transport and publishes an optional token stream. `RuntimeCoordinator` combines the latest allowance and token snapshots into `QuotaDetailFormatter`, which produces a pure presentation model. AppKit renders the model as a fixed token band above the existing scrollable detail rows.

**Tech Stack:** Swift 6, Swift Package Manager, macOS 14 AppKit, XCTest, existing Codex app-server JSON-RPC stdio transport, existing semantic Codex theme/language providers.

## Global Constraints

- Use the official app-server `account/usage/read` method; do not call `/wham/profiles/me`, inspect browser cookies, copy OAuth tokens, or add a second HTTP auth path.
- The current-cycle period is `resetsAt - windowDurationMins * 60` through `resetsAt`; compute the displayed total from filtered daily buckets.
- Keep the product version at `0.3.0`; rebuilds use a local cachebuster only.
- Keep the existing Tibo row directly below the progress bar and above the token band.
- Keep token band and Tibo row above the detail scroll area; Bank rows remain scrollable.
- Support Simplified Chinese, Traditional Chinese, and English fallback through existing `QuotaLocalization`.
- Use semantic AppKit colors for Aqua and Dark Aqua; no hard-coded appearance-specific colors.
- Preserve existing placement, settings hiding, hover/pin behavior, and Tibo dismiss-before-open ordering.
- Preserve the three pre-existing generated build artifacts and do not push GitHub in this phase.

---

### Task 1: Add token usage models, decoder, and cycle normalization

**Files:**
- Modify: `plugins/codex-usage-sidebar/native/Sources/SidebarCore/Models.swift`
- Create: `plugins/codex-usage-sidebar/native/Sources/SidebarCore/TokenUsageDecoder.swift`
- Create: `plugins/codex-usage-sidebar/native/Sources/SidebarCore/TokenUsageWindow.swift`
- Create: `plugins/codex-usage-sidebar/native/Tests/SidebarCoreTests/TokenUsageDecoderTests.swift`
- Create: `plugins/codex-usage-sidebar/native/Tests/SidebarCoreTests/TokenUsageWindowTests.swift`

**Interfaces:**
- `TokenUsageAvailability`: `.available`, `.unavailable`, `.unsupported`.
- `TokenUsageDay(date: Date, tokens: Int64)` with a normalized start-of-day date.
- `TokenUsageSummary(lifetimeTokens: Int64?, peakDailyTokens: Int64?, longestRunningTurnSec: Int?, currentStreakDays: Int?, longestStreakDays: Int?)`.
- `TokenUsageSnapshot(receivedAt: Date, dailyBuckets: [TokenUsageDay], summary: TokenUsageSummary?, availability: TokenUsageAvailability)`.
- `TokenUsageDecoder.decodeResponse(_:receivedAt:) throws -> TokenUsageSnapshot`.
- `TokenUsageWindow.currentCycle(from:allowance:now:timeZone:) -> TokenUsageCycle?`, where `TokenUsageCycle` contains normalized daily days and `totalTokens: Int64`.

- [ ] **Step 1: Write failing decoder tests**

Add tests that pass this response to `TokenUsageDecoder.decodeResponse` and assert the camelCase fields, sparse buckets, and summary values are decoded:

```swift
let data = Data(#"{
  "summary": { "lifetimeTokens": 1234567, "peakDailyTokens": 900000,
    "longestRunningTurnSec": 10, "currentStreakDays": 2, "longestStreakDays": 5 },
  "dailyUsageBuckets": [
    { "startDate": "2026-08-13", "tokens": 1200 },
    { "startDate": "2026-08-15", "tokens": 3400 }
  ]
}"#.utf8)
let snapshot = try TokenUsageDecoder.decodeResponse(
    data,
    receivedAt: Date(timeIntervalSince1970: 1_800_000_000)
)
XCTAssertEqual(snapshot.dailyBuckets.map(\.tokens), [1200, 3400])
XCTAssertEqual(snapshot.summary?.lifetimeTokens, 1_234_567)
```

Also add tests for negative tokens, invalid dates, malformed JSON, and a JSON-RPC `-32601` method-not-found response producing the `.unsupported` decoding error.

- [ ] **Step 2: Run the focused tests and verify failure**

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcrun swift test --package-path plugins/codex-usage-sidebar/native \
  --filter TokenUsageDecoderTests
```

Expected: FAIL because the model and decoder symbols do not exist.

- [ ] **Step 3: Implement the model and decoder**

Decode only `summary` and `dailyUsageBuckets`; coerce numeric JSON values through `NSNumber`, reject booleans, clamp no values silently, and throw typed errors for invalid dates/tokens. Parse `yyyy-MM-dd` as a Gregorian date in the supplied system calendar/time zone and normalize every bucket to the calendar start of day. Treat `-32601` as `.unsupported` and other response errors as `.unavailable`.

- [ ] **Step 4: Add failing cycle-window tests**

Create an allowance with `resetsAt = 2026-08-20 19:31`, `windowDurationMins = 10080`, and buckets on Aug 12 through Aug 21. Assert that the cycle contains Aug 13 through Aug 15 only, inserts zero-token Aug 14 when absent, excludes future/out-of-window buckets, and sums only included values.

- [ ] **Step 5: Implement `TokenUsageWindow.currentCycle`**

Derive `periodStart` from `resetsAt` and `windowDurationMins`, iterate calendar dates from the start date through `min(now, resetsAt)`, map bucket dates to counts, fill missing dates with zero, and return `nil` when the allowance has no positive window duration.

- [ ] **Step 6: Run focused tests and commit**

Run both focused filters and expect PASS. Commit only the model/decoder/window source and tests:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcrun swift test --package-path plugins/codex-usage-sidebar/native \
  --filter TokenUsageDecoderTests --filter TokenUsageWindowTests
git add plugins/codex-usage-sidebar/native/Sources/SidebarCore/Models.swift \
  plugins/codex-usage-sidebar/native/Sources/SidebarCore/TokenUsageDecoder.swift \
  plugins/codex-usage-sidebar/native/Sources/SidebarCore/TokenUsageWindow.swift \
  plugins/codex-usage-sidebar/native/Tests/SidebarCoreTests/TokenUsageDecoderTests.swift \
  plugins/codex-usage-sidebar/native/Tests/SidebarCoreTests/TokenUsageWindowTests.swift
git commit -m "feat: decode current-cycle token usage"
```

### Task 2: Integrate `account/usage/read` into `AppServerClient`

**Files:**
- Modify: `plugins/codex-usage-sidebar/native/Sources/SidebarCore/AppServerClient.swift`
- Modify: `plugins/codex-usage-sidebar/native/Tests/SidebarCoreTests/AppServerClientTests.swift`

**Interfaces:**
- Add `public nonisolated let tokenUsages: AsyncStream<TokenUsageSnapshot>`.
- `refresh()` sends at most one pending `account/rateLimits/read` and one pending `account/usage/read`.
- Initialization requests both methods after the `initialized` notification.

- [ ] **Step 1: Write failing client tests**

Extend the fake transport tests to assert that initialization emits both request methods, a valid usage response reaches `client.tokenUsages`, duplicate refresh calls do not enqueue duplicate usage requests, and a method-not-found response yields an unsupported snapshot without preventing rate-limit snapshots.

- [ ] **Step 2: Run the focused client tests and verify failure**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcrun swift test --package-path plugins/codex-usage-sidebar/native \
  --filter AppServerClientTests
```

Expected: FAIL because `tokenUsages` and the second pending method do not exist.

- [ ] **Step 3: Implement independent token request state**

Add `.readTokenUsage` to `PendingMethod`, a token stream continuation, and a `tokenUsageReadNeededAfterPending` flag. After initialization, request both methods. On response, decode and yield a snapshot; on typed unsupported/unavailable errors, yield a snapshot with the corresponding availability and an empty bucket list. Keep the existing rate-limit response and notification path unchanged.

- [ ] **Step 4: Run client tests and commit**

Run the focused filter and the full `SidebarCoreTests` target. Commit:

```bash
git add plugins/codex-usage-sidebar/native/Sources/SidebarCore/AppServerClient.swift \
  plugins/codex-usage-sidebar/native/Tests/SidebarCoreTests/AppServerClientTests.swift
git commit -m "feat: stream account token usage"
```

### Task 3: Add localized token presentation and reset countdown formatting

**Files:**
- Modify: `plugins/codex-usage-sidebar/native/Sources/SidebarCore/QuotaLocalization.swift`
- Modify: `plugins/codex-usage-sidebar/native/Sources/SidebarCore/QuotaDetailFormatter.swift`
- Modify: `plugins/codex-usage-sidebar/native/Sources/SidebarCore/QuotaCountdownSegments.swift`
- Create: `plugins/codex-usage-sidebar/native/Sources/SidebarCore/QuotaResetCountdownFormatter.swift`
- Modify: `plugins/codex-usage-sidebar/native/Tests/SidebarCoreTests/QuotaDetailFormatterTests.swift`
- Modify: `plugins/codex-usage-sidebar/native/Tests/SidebarCoreTests/QuotaCountdownSegmentsTests.swift`
- Create: `plugins/codex-usage-sidebar/native/Tests/SidebarCoreTests/QuotaResetCountdownFormatterTests.swift`

**Interfaces:**
- `QuotaTokenUsageDay(label: String, tokens: Int64, isCurrentDay: Bool)`.
- `QuotaTokenUsagePresentation(title: String, totalLabel: String, totalTokens: Int64, days: [QuotaTokenUsageDay], delayNote: String, availability: TokenUsageAvailability)`.
- `QuotaDetailContent.tokenUsage: QuotaTokenUsagePresentation?`.
- `QuotaDetailFormatter.content(snapshot:tokenUsage:now:language:timeZone:)` with `tokenUsage` defaulting to `nil` for existing call sites.
- `QuotaResetCountdownFormatter.string(from:to:language:)` returns `4天23小时`, `4天23小時`, or `4d 23h` while retaining a compact fallback for sub-hour values.

- [ ] **Step 1: Add failing localization/formatter tests**

Use an allowance reset at `2025-08-19 19:30` and `now = 2025-08-14 20:30` to assert:

```swift
XCTAssertTrue(content.rows.contains {
    $0.label == "下次重置" &&
    $0.value == "4天23小时（2025/08/19 19:30）"
})
```

Add equivalent Traditional Chinese and English assertions, plus a `QuotaTokenUsagePresentation` assertion with a period total and seven localized day labels. Add segment tests proving only the `4` and `23` interval numbers are `.digits`; the timestamp numbers remain `.plain`.

- [ ] **Step 2: Run focused tests and verify failure**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcrun swift test --package-path plugins/codex-usage-sidebar/native \
  --filter QuotaDetailFormatterTests --filter QuotaCountdownSegmentsTests \
  --filter QuotaResetCountdownFormatterTests
```

Expected: FAIL because the token presentation and new reset format are not implemented.

- [ ] **Step 3: Implement localized presentation**

Add token labels, delay/unavailable copy, compact token number formatting (`K`, `M`, `B` with locale-safe decimal separator), and date labels to `QuotaLocalization`. Have the formatter call `TokenUsageWindow.currentCycle`, sum the cycle, produce one day entry per normalized date, and use the existing Tibo entry unchanged. Split next-reset formatting from Bank expiry formatting so the requested ISO-like reset timestamp does not change Bank display.

- [ ] **Step 4: Implement countdown segmentation**

Extend `QuotaCountdownSegmenter` to recognize localized interval prefixes before the reset timestamp (`4天23小时`, `4天23小時`, `4d 23h`) and mark only interval numbers/units as emphasis. Keep Bank values using the existing parenthesized compact interval parser.

- [ ] **Step 5: Run focused tests and commit**

Run the focused filters and the existing localization/formatter suite. Commit the presentation and formatting sources/tests:

```bash
git add plugins/codex-usage-sidebar/native/Sources/SidebarCore/QuotaLocalization.swift \
  plugins/codex-usage-sidebar/native/Sources/SidebarCore/QuotaDetailFormatter.swift \
  plugins/codex-usage-sidebar/native/Sources/SidebarCore/QuotaCountdownSegments.swift \
  plugins/codex-usage-sidebar/native/Sources/SidebarCore/QuotaResetCountdownFormatter.swift \
  plugins/codex-usage-sidebar/native/Tests/SidebarCoreTests/QuotaDetailFormatterTests.swift \
  plugins/codex-usage-sidebar/native/Tests/SidebarCoreTests/QuotaCountdownSegmentsTests.swift \
  plugins/codex-usage-sidebar/native/Tests/SidebarCoreTests/QuotaResetCountdownFormatterTests.swift
git commit -m "feat: format localized token usage details"
```

### Task 4: Render the fixed token band in the native popover

**Files:**
- Modify: `plugins/codex-usage-sidebar/native/Sources/SidebarCore/QuotaDetailLayout.swift`
- Modify: `plugins/codex-usage-sidebar/native/Sources/CodexUsageSidebar/QuotaDetailPanel.swift`
- Create: `plugins/codex-usage-sidebar/native/Sources/CodexUsageSidebar/QuotaTokenUsageView.swift`
- Modify: `plugins/codex-usage-sidebar/native/Tests/SidebarCoreTests/QuotaDetailLayoutTests.swift`
- Modify: `plugins/codex-usage-sidebar/native/Tests/CodexUsageSidebarTests/QuotaDetailCardVisualTests.swift`

**Interfaces:**
- Extend `QuotaDetailInformationFrames` with `tokenBand` and keep `control` as the Tibo row frame.
- `QuotaDetailLayout.informationFrames(in:tokenUsageVisible:)` returns deterministic Tibo/token/detail frames.
- `QuotaTokenUsageView(frame:presentation:remainingPercent:)` renders semantic bars and delay copy.
- `QuotaDetailCardView` accepts `content.tokenUsage` and renders the token band between the Tibo row and the scroll view.

- [ ] **Step 1: Write failing layout/visual tests**

Assert the Tibo frame remains directly below the progress separator, the token band begins below the Tibo bottom divider, the row area begins below the token band, and all frames remain inside the card. Add a visual fixture with seven days and a long Bank list; assert a token view exists, has seven bars, and the scroll view remains enabled.

- [ ] **Step 2: Run focused UI tests and verify failure**

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcrun swift test --package-path plugins/codex-usage-sidebar/native \
  --filter QuotaDetailLayoutTests --filter QuotaDetailCardVisualTests
```

Expected: FAIL because the layout has no token frame/view and `QuotaDetailContent` has no token presentation.

- [ ] **Step 3: Implement deterministic layout**

Add a compact token band height that fits within the existing 300-point card and 480-point maximum before detail scrolling. Make `contentHeight` and `rowAreaFrame` account for `tokenUsageVisible`; keep `maximumHeight` and frame anchoring behavior unchanged. Add a horizontal scroll region inside the token band only when the day series cannot fit the minimum bar width.

- [ ] **Step 4: Implement `QuotaTokenUsageView`**

Use AppKit labels and custom drawing for bars. Use `QuotaColorScale.components(remainingPercent:)` for the current-day bar and countdown accent; use `secondaryLabelColor` with alpha for other bars. Set accessibility values for the chart summary and each day. Do not cache colors outside `appearance.performAsCurrentDrawingAppearance`.

- [ ] **Step 5: Wire the card and run visual fixtures**

Render the Tibo row, token band, and existing scroll view in the approved order. Keep existing Tibo hover/activation and version badge code unchanged. Run the focused tests with `CUS_VISUAL_OUTPUT_DIR` and inspect all three languages in Aqua/Dark Aqua.

- [ ] **Step 6: Commit the native UI**

```bash
git add plugins/codex-usage-sidebar/native/Sources/SidebarCore/QuotaDetailLayout.swift \
  plugins/codex-usage-sidebar/native/Sources/CodexUsageSidebar/QuotaDetailPanel.swift \
  plugins/codex-usage-sidebar/native/Sources/CodexUsageSidebar/QuotaTokenUsageView.swift \
  plugins/codex-usage-sidebar/native/Tests/SidebarCoreTests/QuotaDetailLayoutTests.swift \
  plugins/codex-usage-sidebar/native/Tests/CodexUsageSidebarTests/QuotaDetailCardVisualTests.swift
git commit -m "feat: render token usage popover band"
```

### Task 5: Combine token stream with runtime lifecycle

**Files:**
- Modify: `plugins/codex-usage-sidebar/native/Sources/CodexUsageSidebar/RuntimeCoordinator.swift`
- Modify: `plugins/codex-usage-sidebar/native/Sources/CodexUsageSidebar/main.swift` only if diagnostic stream coverage needs a token status line
- Modify: `plugins/codex-usage-sidebar/native/Tests/CodexUsageSidebarTests/RuntimeCoordinatorTests.swift` if present; otherwise add focused coordinator coverage in the existing test target.

**Interfaces:**
- `RuntimeCoordinator` stores `tokenUsageSnapshot: TokenUsageSnapshot?` and a cancellable `tokenUsageTask`.
- `replaceClient(using:)` subscribes to `newClient.tokenUsages` and clears stale token data when the app-server changes.
- `QuotaDetailFormatter.content` receives the latest optional token snapshot in `reconcileOverlay()`.

- [ ] **Step 1: Write failing lifecycle tests**

Verify that a token snapshot updates the detail model without replacing the allowance snapshot, that replacing the app-server clears stale token data, and that `.unsupported` still leaves the quota indicator visible.

- [ ] **Step 2: Implement the coordinator subscription**

Cancel the token task alongside the existing snapshot task, subscribe to `newClient.tokenUsages`, store each value, and call `reconcileOverlay()`. Pass the token value to the formatter. Keep the settings-page guard and placement calculations untouched.

- [ ] **Step 3: Run lifecycle tests and commit**

Run the coordinator/lifecycle tests and commit:

```bash
git add plugins/codex-usage-sidebar/native/Sources/CodexUsageSidebar/RuntimeCoordinator.swift \
  plugins/codex-usage-sidebar/native/Sources/CodexUsageSidebar/main.swift \
  plugins/codex-usage-sidebar/native/Tests/CodexUsageSidebarTests
git commit -m "feat: connect token usage to runtime overlay"
```

### Task 6: Full verification, rebuild, reinstall, and local runtime acceptance

**Files:**
- Modify generated only through build scripts: `plugins/codex-usage-sidebar/.codex-plugin/plugin.json`, `plugins/codex-usage-sidebar/assets/Codex Usage Sidebar.app/Contents/Info.plist`, and the bundled companion binary.
- Do not hand-edit these generated files.

- [ ] **Step 1: Run the complete Swift suite**

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
uv run --with PyYAML python /Users/byctor/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py plugins/codex-usage-sidebar
CUS_REBUILT_PAYLOAD=1 bash scripts/validate-public-repo.sh
git diff --check
```

- [ ] **Step 3: Rebuild and reinstall the worktree payload**

```bash
python3 /Users/byctor/.codex/skills/.system/plugin-creator/scripts/update_plugin_cachebuster.py plugins/codex-usage-sidebar
bash plugins/codex-usage-sidebar/scripts/build-companion.sh
bash plugins/codex-usage-sidebar/scripts/sidebar-control.sh repair \
  --plugin-root "$PWD/plugins/codex-usage-sidebar"
```

- [ ] **Step 4: Verify real Codex behavior**

Use the installed runtime and inspect the actual popover in Aqua and Dark Aqua. Verify:

- settings page hides the indicator;
- conversation home restores it in the content header/sidebar placement;
- Tibo row remains clickable and dismisses before opening its exact URL;
- token total and daily values update from the official app-server response;
- unsupported/unavailable token data does not hide quota data;
- reset output shows the requested date format and enlarged colored day/hour numbers;
- long Bank lists scroll without overlap.

- [ ] **Step 5: Final board checkpoint and local handoff**

Run board validation, record changed files and exact verification results, and leave the branch local. Do not push GitHub or alter the main checkout's unrelated generated artifacts.
