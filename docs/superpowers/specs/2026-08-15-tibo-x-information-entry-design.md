# Tibo X Information Entry Design

## Objective

Add a native, localized Tibo information entry to the Codex quota popover. The entry opens `https://x.com/thsottiaux` in the system default browser, dismisses the quota popover before navigation, and leaves a clean extension boundary for a later Tibo-post summary or reset-date prediction feature.

This phase must produce a locally installed and visually verified macOS companion. It must not fetch X content, require an X account, add telemetry, or publish changes to GitHub.

## Approved Visual Direction

The user selected a combined direction:

- Use concept C's placement: the Tibo entry sits directly below the quota progress bar and above the quota detail rows.
- Use concept A's styling: one restrained native link row, a compact monochrome X icon, native Codex typography, a subtle separator, a trailing external-link arrow, and a low-contrast hover surface.
- Do not use concept C's blue card, blue status dot, tinted banner background, or two-line promotional copy.
- Preserve the quota title, version badge, percentage, progress bar, countdown emphasis, Bank rows, and current 300-point popover width.

The result should feel like a native Codex information source rather than an advertisement or an additional quota metric.

## Localized Copy

The existing Codex language resolution remains the source of truth.

| Language | Visible link copy | Accessibility description |
| --- | --- | --- |
| Simplified Chinese | `Tibo 的 X 动态` | `在浏览器中打开 Tibo 的 X 主页` |
| Traditional Chinese | `Tibo 的 X 動態` | `在瀏覽器中開啟 Tibo 的 X 主頁` |
| English | `Tibo on X` | `Open Tibo's X profile in the browser` |

Unsupported Codex languages continue to resolve to English through the existing language policy.

## Architecture

### SidebarCore presentation model

Add an optional structured information entry to `QuotaDetailContent`. The model contains:

- visible localized title;
- localized accessibility description;
- validated HTTPS destination URL.

`QuotaDetailFormatter` creates the Tibo entry using the same `QuotaLocalization` instance used for the quota rows. The URL is fixed to `https://x.com/thsottiaux` in this release. Keeping the entry in the presentation model prevents the AppKit view from owning localization or destination policy and provides a stable place for future summary metadata.

### Pure layout policy

Extend `QuotaDetailLayout` with deterministic frames for the information-entry band. The title/progress area remains unchanged. The new band occupies the area between the progress separator and the quota rows, increasing `headerHeight` while preserving:

- 300-point card width;
- 480-point maximum height;
- eight-point indicator-to-popover gap;
- leading-edge alignment with the quota button;
- vertical scrolling for large Bank lists.

The entry has a full-width interaction target with 12-point horizontal card insets. Its visible hover surface uses an eight-point continuous corner radius and the same low-contrast semantic hover treatment as the quota control.

### AppKit view and activation boundary

`QuotaDetailCardView` renders the presentation model with a dedicated native `NSControl` subclass. The control owns only rendering and pointer state:

- compact monochrome X glyph;
- one-line localized label;
- trailing external-link arrow;
- transparent resting state;
- subtle semantic hover/pressed state;
- pointing-hand cursor and accessibility link semantics.

The control emits the selected URL through a closure. `QuotaDetailPanel` forwards the activation to `OverlayPanel`; it does not open the browser itself. `OverlayPanel` resets the pin/hover detail state, hides the detail panel, and then calls the injected external URL opener. Production uses `NSWorkspace.shared.open`.

This ordering guarantees that the quota popover disappears even if the browser reuses an existing window or does not immediately take focus. The quota indicator itself remains governed by the existing application-activation policy.

## Interaction States

- Hovering the quota indicator continues to reveal the popover.
- Clicking the quota indicator continues to pin or unpin the popover.
- Moving into the Tibo row keeps the popover visible through the existing detail-frame hover detection.
- Resting Tibo row: transparent and visually subordinate to quota data.
- Hovered Tibo row: subtle semantic background, pointing-hand cursor, unchanged text contrast.
- Pressed Tibo row: slightly stronger semantic background without movement or animation.
- Activating the row: dismiss the detail popover, clear pinned state, then open the exact HTTPS profile URL in the system default browser.
- Opening failure: keep the detail popover dismissed and allow the existing quota button to reopen it; no blocking alert is shown for the fixed trusted URL.

## Theme And Accessibility

- Use AppKit semantic colors only: `labelColor`, `secondaryLabelColor`, `windowBackgroundColor`, and semantic alpha treatments derived from `labelColor`.
- Let the existing resolved Codex appearance drive light and dark rendering.
- Expose the entry as an accessibility link with the localized description.
- Keep a minimum 32-point interaction height and a 24-point icon target.
- Do not rely on color alone: the X glyph, label, and external-link arrow communicate purpose in both themes.
- Do not add continuous or decorative animation.

## Testing Strategy

Follow test-driven development and verify each new behavior against a failing test first.

1. Localization tests prove all three visible titles and accessibility descriptions.
2. Formatter tests prove the exact validated HTTPS destination and language-specific presentation content.
3. Layout tests prove the information band and row area never overlap, the 300-point width remains unchanged, and maximum-height scrolling still applies.
4. Interaction tests prove external-link activation resets pinned detail state before requesting navigation.
5. The full Swift package suite proves existing quota formatting, titlebar placement, installer, and Windows-shared contracts remain intact.
6. The repository validators and plugin validator prove packaging and manifest consistency.
7. A local build/install plus Codex visual inspection proves resting, hover, click, light-theme, and dark-theme behavior in the real application.

## Future Extension Boundary

A later, separately designed phase may extend the information-entry model with a latest-post summary, timestamp, fetch status, or prediction confidence. That phase must make an explicit choice among the official X API, a user-provided feed, or a separate backend and must address authentication, rate limits, caching, privacy, source attribution, and prediction uncertainty.

The current implementation deliberately does not introduce a network client, HTML scraping, background polling, post analysis, or reset-date prediction. The stable presentation model and activation boundary are the only future-facing seams added now.

## Delivery Constraints

- Keep the product version at `0.3.0`; use a Codex cachebuster for the local development install.
- Preserve the three pre-existing modified build artifacts in the main checkout.
- Build and test from the isolated `codex/tibo-x-entry` worktree.
- Do not push or create a GitHub pull request during local validation.
- Do not hand-edit marketplace configuration; use the plugin cachebuster and reinstall workflow.

## Acceptance Criteria

- The Tibo entry appears below the progress bar and above quota detail rows.
- Its resting and hover treatment matches the approved C-placement/A-style direction in both Codex themes.
- It displays the correct Simplified Chinese, Traditional Chinese, or English copy from the effective Codex language.
- Clicking it dismisses the quota popover and opens `https://x.com/thsottiaux` with the system default browser.
- Existing hover-to-show and click-to-pin behavior remains unchanged outside the link activation.
- Large Bank lists remain scrollable and no header, entry, or row overlaps occur.
- All automated tests and validators pass.
- The locally installed plugin is verified in the running Codex app without publishing to GitHub.
