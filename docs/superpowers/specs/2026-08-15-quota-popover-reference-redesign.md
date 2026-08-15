# Quota Popover Reference Redesign

## Status

Approved visual direction: the user-provided reference image is the single visual source of truth. The bottom Jace user area and question-mark button are explicitly excluded.

## Goal

Rework the native quota popover so its layout, typography, materials, colors, content hierarchy, and spacing closely match the supplied reference image while preserving live Codex data, multilingual behavior, Tibo X activation, settings-page hiding, and existing placement behavior.

## Visual source of truth

- Preserve the reference card's dark translucent material, subtle border, soft shadow, large continuous corner radius, generous horizontal padding, and thin section dividers.
- Use the reference hierarchy: avatar/title/version at the top, large remaining percentage, progress track, outlined Tibo X row, token usage section, detailed quota rows, then a clean bottom inset.
- Do not render a Jace footer, account row, or question-mark/help button inside the quota popover.
- Treat the reference dark appearance as authoritative. Aqua/light appearance uses the same geometry and semantic color roles with an inverted material/label treatment; it must not introduce a separate layout.
- Preserve the existing quota accent scale. The current remaining-percentage color drives the percentage, progress fill, current-day token bar, and highlighted reset day/hour numbers.

## Content requirements

- Keep the live `account/rateLimits/read` and `account/usage/read` app-server data paths unchanged.
- Keep the exact localized Tibo links and dismiss-before-open behavior.
- Always reserve seven daily chart columns. Use normalized current-cycle buckets for elapsed dates; future dates in the active cycle render as zero-height/empty columns with localized date labels, never fabricated token values.
- Show the period total, daily token labels, a current-day accent, a neutral historical/future treatment, the existing delay note, and a compact legend matching the reference hierarchy.
- Preserve all plan, quota-window, reset, Credits, Bank, and freshness content. Bank rows remain scrollable when content exceeds the available height.
- Reset values use the existing localized forms: `4天23小时（2025/08/19 19:30）`, `4天23小時（2025/08/19 19:30）`, and `4d 23h (2025/08/19 19:30)`, with only interval numbers enlarged and accented.
- Dates and token counts are examples in the reference only; runtime values always come from the live snapshot.

## Geometry and typography

- Increase the popover width and maximum height from the compact 300/480 layout to a reference-like wide card while clamping to the visible screen and retaining safe placement beside the indicator.
- Use a two-column detail row: linear icon column, left label, right-aligned value, with separators between rows.
- Use a larger title and remaining percentage than the current compact card, a compact version capsule aligned to the title baseline, and a 4–6 px progress track.
- Keep the Tibo row full-width with an outlined rounded container, monochrome X icon, localized label, and trailing external-link glyph.
- Keep the token chart fixed above the scroll view. Seven columns must fit the wide card without a horizontal scroller in the reference layout.

## Assets and implementation boundaries

- Reuse existing semantic AppKit colors, `QuotaColorScale`, localization, and app-server streams.
- Reuse a stable avatar asset only if it is available from the current Codex/plugin asset boundary; otherwise use a packaged neutral avatar placeholder rather than scraping browser state.
- Keep AppKit rendering native; no webview or direct browser DOM dependency.
- Do not alter the right/left sidebar placement algorithms or settings-page visibility rules.
- Product version remains `0.3.0`; local cachebuster changes are generated only by the build script.

## Acceptance criteria

1. A local runtime screenshot in Dark Aqua visually matches the supplied reference hierarchy, materials, colors, typography scale, separators, and spacing, without Jace/question footer content.
2. Aqua/light appearance preserves the same geometry and readable semantic contrast.
3. The chart always presents seven columns, including zero/empty future columns when the current cycle has not reached all seven days.
4. Long Bank lists scroll inside the lower detail region without covering the token band or Tibo row.
5. Tibo opens `https://x.com/thsottiaux` after dismissing the popover.
6. Settings pages hide the indicator; conversation home restores it in the existing content-header/sidebar placement.
7. Existing data, language, lifecycle, placement, signing, plugin, and public-repository tests remain green.
