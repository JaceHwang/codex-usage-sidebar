# Emphasized Countdown Typography Design

## Goal

Make compact reset intervals such as `（5d21h）` and `(2d6h)` faster to scan in the quota popover without adding a capsule, background, border, or extra width.

## Approved Visual Direction

- Keep the existing date, row layout, card surface, and alignment.
- Render interval digits in the same dynamic quota color used by the percentage and progress state.
- Enlarge and strengthen the digits relative to the row value.
- Render `d`, `h`, and `m` as smaller secondary units on the same baseline.
- Render parentheses with the same muted treatment as the units.
- Apply the same semantic hierarchy in Codex light and dark themes. Dynamic AppKit label colors provide theme contrast; the quota accent remains driven by `QuotaColorScale`.
- Preserve Simplified Chinese, Traditional Chinese, and English parentheses and suffixes.

## Architecture

Add a platform-neutral compact-duration segmenter to `SidebarCore`. It identifies the final parenthesized interval emitted by `QuotaDetailFormatter` and classifies characters as plain text, punctuation, digits, units, or suffix text. `QuotaDetailPanel` turns those segments into an `NSAttributedString` using AppKit fonts and theme-aware colors.

Row measurement uses the same attributed-string builder as rendering so the emphasized digits cannot introduce clipping or accidental wrapping. Rows without a compact interval retain the current plain label rendering.

## Typography

- Base row value: 12 pt regular, `labelColor`.
- Interval digits: 14 pt semibold, dynamic `QuotaColorScale` accent.
- Interval units: 10 pt medium, `secondaryLabelColor`.
- Parentheses and interval suffix text: 10 pt regular, `secondaryLabelColor`.
- No baseline offset, capsule, fill, outline, shadow, or underline.

## Validation

- Unit-test segmentation for Simplified Chinese, Traditional Chinese, English, past intervals, status suffixes, and non-duration values.
- Run focused segmenter and layout tests, then the complete Swift package suite.
- Build and reinstall through the supported plugin update flow.
- Inspect the running companion in both Codex light and dark themes and confirm the rows remain single-line and readable.
- Validate the plugin manifest and public-repository checks before publishing.
