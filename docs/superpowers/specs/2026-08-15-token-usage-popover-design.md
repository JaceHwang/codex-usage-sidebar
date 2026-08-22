# Token Usage Popover Design

## Objective

Add current-quota-cycle token usage to the native Codex Usage Sidebar quota popover. The popover will show a daily breakdown and a period total, reuse Codex's authenticated app-server data channel, retain the existing Tibo X information entry, and keep all existing quota, Bank, theme, language, placement, and pinning behavior intact.

This phase is macOS-first because the current companion is native AppKit. The data model and formatter boundaries must remain portable enough for the Windows implementation to consume the same protocol concepts later.

## Approved Visual Direction

The user approved the generated B-based concept with these fixed decisions:

- Keep the existing Codex quota header, version badge, percentage, progress bar, countdown emphasis, Bank rows, and native popover surface.
- Render the existing `Tibo 的 X 动态` / `Tibo 的 X 動態` / `Tibo on X` entry directly below the progress bar and above token usage.
- Render a compact token usage band below the Tibo entry and above the detail rows.
- Show a right-aligned current-cycle total, compact daily bars with numeric labels above each bar, and an orange current-day accent.
- Keep the token band and Tibo entry visible above the detail scroll area; large Bank lists remain scrollable below them.
- Use semantic AppKit colors for Aqua and Dark Aqua. Do not introduce a new card, gradient, dashboard chrome, or independent accent palette.

The generated concept is a visual reference for hierarchy and emphasis, not a pixel-perfect asset. Native AppKit metrics and the existing 300-point popover width remain the source of truth for implementation.

## Data Source and Trust Boundary

### Official app-server method

Use the already-authenticated Codex app-server stdio session owned by `AppServerClient`:

```text
account/usage/read
```

The current Codex app-server was probed locally and returned the following stable protocol shape:

```json
{
  "summary": {
    "lifetimeTokens": 1900666579,
    "peakDailyTokens": 362549179,
    "longestRunningTurnSec": 18704,
    "currentStreakDays": 9,
    "longestStreakDays": 25
  },
  "dailyUsageBuckets": [
    { "startDate": "2026-08-13", "tokens": 166026932 },
    { "startDate": "2026-08-14", "tokens": 5689963 }
  ]
}
```

The implementation must not call `/wham/profiles/me` directly, inspect browser cookies, copy OAuth tokens, or add a second HTTP authentication path. The official web profile endpoint is useful evidence for the protocol shape, but app-server is the supported integration boundary for this plugin.

### Quota-cycle boundary

`account/rateLimits/read` already provides `primary.resetsAt` and `primary.windowDurationMins`. The token usage period is derived as:

```text
periodStart = resetsAt - windowDurationMins * 60 seconds
periodEnd = resetsAt
```

Only daily buckets whose calendar date overlaps the active period and is not in the future are included. The period total is the sum of the included daily buckets, not `summary.lifetimeTokens`; the lifetime value remains an optional diagnostic field and is not shown as the current-cycle total.

The daily series is normalized to one bucket per calendar day in the active period. Missing dates are filled with zero, so the chart has deterministic labels and no visual gaps. If the server omits `windowDurationMins`, token usage is still decoded but the UI reports that the current-cycle total is unavailable rather than guessing a period.

### Refresh and freshness

- Request token usage after initialization and when the existing quota refresh completes.
- Refresh at the same user-visible cadence as quota data, with a minimum in-flight guard so opening/pinning the popover cannot create duplicate requests.
- Reuse the last successful token snapshot while a refresh is pending.
- The official profile copy indicates usage data can be delayed by up to approximately six hours. Show this as a localized muted note; do not imply per-request real-time precision.
- A token response is independent from a rate-limit response. A token failure must not hide or invalidate the quota percentage, reset time, Bank details, or Tibo entry.

## Presentation Model

Add a separate `TokenUsageSnapshot` in `SidebarCore` rather than adding token fields directly to `AllowanceSnapshot`:

- `receivedAt: Date`
- `dailyBuckets: [TokenUsageDay]`
- `summary: TokenUsageSummary?`
- `availability: available | unavailable | unsupported`

`TokenUsageDay` contains a normalized local-calendar date and a non-negative token count. `TokenUsageSummary` retains the official lifetime/peak fields for diagnostics, while the formatter computes `currentPeriodTotal` from the filtered daily buckets and the active `AllowanceSnapshot`.

The coordinator publishes a combined view model containing the latest allowance and optional token snapshot. Existing quota views continue to accept an allowance-only value, so an unsupported or failed token endpoint is a non-breaking optional extension.

## UI Composition

### Token band

The token band is a dedicated native AppKit view with deterministic layout metrics:

- heading: localized `Token 用量` / `Token 用量` / `Token usage`;
- trailing summary: localized `本周期总计 1.24M tokens` / equivalent English and Traditional Chinese copy;
- daily chart: one compact bar per normalized day, numeric token label above, date label below;
- current day: same quota progress accent used by the percentage and highlighted countdown numbers;
- other days: semantic secondary fill, never hard-coded light/dark colors;
- muted delay note: localized copy equivalent to “Usage data may be delayed by up to 6 hours”;
- accessibility: the chart exposes a concise summary and each bar exposes its date and token count.

The chart must remain legible at the existing popover width. For periods wider than the available content width, the chart receives an internal horizontal scroll region; it must not resize or overlap the detail-value column.

### Tibo entry

Keep the existing `QuotaInformationLinkButton` unchanged in behavior and copy. It remains the full-width native single-line link row between the progress area and the token band. Clicking it still dismisses the popover and opens `https://x.com/thsottiaux` in the system browser.

### Countdown emphasis

Replace the reset detail's single attributed string with structured segments:

- Simplified Chinese: `4天23小时（2025/08/19 19:30）`
- Traditional Chinese: `4天23小時（2025/08/19 19:30）`
- English: `4d 23h (2025/08/19 19:30)`

The remaining-day and remaining-hour numbers are rendered separately using the existing quota accent, a semibold font, and a modestly larger point size. Units, parentheses, and the fixed 24-hour `yyyy/MM/dd HH:mm` timestamp use the existing secondary/primary detail typography. The formatter must handle zero days, zero hours, and sub-hour durations without producing empty or misleading segments.

## Localization

Extend the existing three-language localization boundary only:

- Simplified Chinese (`zh-CN`)
- Traditional Chinese (`zh-TW` / `zh-HK` policy already used by the plugin)
- English fallback for unsupported languages

All token labels, chart accessibility descriptions, delay notes, unavailable states, and countdown units go through `QuotaLocalization`. No new language detection logic is introduced.

## Failure and Compatibility Behavior

- If `account/usage/read` is unsupported by an older Codex app-server, classify it as `unsupported`, keep the plugin running, and render a compact localized unavailable state in the token band.
- If the response is malformed, classify it as `unavailable`, retain the last successful snapshot if one exists, and keep the existing quota content visible.
- If no successful token data exists, the token band shows its heading and a native empty/unavailable message instead of fabricated zeroes.
- A missing or invalid `windowDurationMins` prevents a current-cycle total from being computed; historical daily data must not be mislabeled as current-cycle data.
- If Codex navigates to settings, the existing settings visibility gate hides the whole quota indicator. Returning to the conversation home restores the header/sidebar indicator and token data without requiring a plugin reinstall.
- Theme changes redraw the token band and countdown attributed strings through semantic colors and fonts; no cached appearance-specific colors are stored.

## Testing Strategy

Use test-driven development: add a failing test before each production behavior.

1. **Protocol decoding**
   - Decode a valid `account/usage/read` response with summary and sparse buckets.
   - Normalize dates, reject negative/non-numeric token counts, and classify malformed/unsupported responses.
2. **Cycle filtering and totals**
   - Filter buckets using `resetsAt` and `windowDurationMins`.
   - Fill missing days with zero and compute the exact current-cycle sum.
   - Verify future buckets and out-of-window historical buckets are excluded.
3. **AppServerClient lifecycle**
   - Verify the request is sent after initialization.
   - Verify refresh coalescing and independent token failure behavior.
4. **Formatting and localization**
   - Verify daily labels, compact token units, totals, delay note, unavailable state, and all three language variants.
   - Verify reset output structure and enlarged/highlighted day/hour segments, including zero and sub-hour cases.
5. **Layout and visual fixtures**
   - Verify Tibo row, token band, progress separator, and detail scroll frame never overlap.
   - Render Aqua and Dark Aqua fixtures with a seven-day data set and a long Bank list; inspect resting/hovered Tibo state and highlighted countdown numbers.
6. **Regression and local runtime**
   - Run the complete Swift suite and existing lifecycle/signing/bundle/live app-server validators.
   - Rebuild and reinstall from the worktree, verify settings hiding and conversation-home restoration, verify light/dark themes, and verify Tibo click behavior remains intact.

## Delivery Constraints

- Product version remains `0.3.0` for this feature; use a new local cachebuster only when rebuilding the installed payload.
- Preserve the three existing generated build artifacts in the worktree and do not hand-edit marketplace configuration.
- Keep all feature commits local during this phase; do not push GitHub.
- Do not add a direct web request, browser-cookie access, telemetry, X scraping, or prediction logic.

## Acceptance Criteria

- The native popover shows current-cycle total tokens and one daily bar per day in the active quota period.
- Daily labels show formatted values, the current day uses the quota accent, and missing days are represented without gaps.
- The Tibo X row remains directly below the progress bar and opens the exact existing URL with dismiss-before-open ordering.
- “下次重置” uses the requested date format and visibly emphasizes the remaining-day and remaining-hour numbers in all supported languages.
- Light/dark themes, settings hiding, titlebar/sidebar placement, hover pinning, and Bank scrolling remain unchanged.
- Unsupported or delayed token data degrades gracefully without hiding quota data.
- All automated tests, validators, and local runtime checks pass.
