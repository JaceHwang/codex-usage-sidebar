# Changelog

All notable changes to this project are documented here. The project follows
[Semantic Versioning](https://semver.org/).

## [0.2.1] - 2026-08-09

### Fixed

- Honor an explicit Codex language selected in General settings even when an older renderer
  process still advertises the previous locale.
- Read only the quoted `localeOverride` inside Codex's `[desktop]` configuration table and ignore
  unrelated, malformed, or empty values.
- Preserve Auto behavior by falling through to the effective renderer locale whenever Codex has
  no explicit language override.

## [0.2.0] - 2026-08-09

### Added

- Match Simplified Chinese, Traditional Chinese, and English to the locale Codex is actually
  displaying, including the final resolved language when Codex is set to Auto.
- Fall back from the running renderer locale to Codex preferences and then macOS preferred
  language during startup; unsupported languages safely display English.
- Keep the quota detail card open after a click and dismiss it on the next click while preserving
  the existing hover interaction.
- Report only the mapped language and source in sanitized managed-process diagnostics.

### Changed

- Refresh the effective language once per second and re-render an already visible or pinned card
  without waiting for new quota data or reinstalling the plugin.
- Localize every quota label, date, interval, plan, Bank status, and empty state consistently.

## [0.1.9] - 2026-08-09

### Added

- Show the synchronized companion version in a compact blue outlined badge beside the quota-card
  title.
- Render the filled progress bar as a clipped red-to-orange-to-green spectrum with exact 10%, 49%,
  and 100% palette anchors.
- Publish sanitized runtime state from the active LaunchAgent so status reports its PID, bundle
  version, visibility, anchor source, and indicator frame.

### Fixed

- Re-sign the copied companion with the stable local identity when available, preventing plugin
  reinstall from changing the Accessibility code identity and falling back to the wrong position.
- Compare payload fingerprints instead of signed executable bytes, so installer-side signing does
  not cause perpetual replacement.
- Keep the complete quota title, compact version badge, remaining percentage, and spacing aligned
  without truncation.

## [0.1.8] - 2026-08-09

### Fixed

- Build release artifacts on the macOS 26 ARM64 runner with Xcode and macOS SDK 26.5 so the
  installed titlebar control retains the same AppKit behavior as the verified local build.
- Reject release binaries compiled for another architecture or an older macOS SDK before they can
  be packaged and promoted.

## [0.1.7] - 2026-08-09

### Fixed

- Keep the titlebar quota control visible at a safe right-side fallback position while Codex's
  accessibility tree is unavailable or incomplete during startup.
- Continue scanning after fallback placement and automatically restore the exact 8-point Open
  Location gap as soon as the native control is resolved.

## [0.1.6] - 2026-08-09

### Fixed

- Keep the last valid Open Location accessibility element during transient incomplete scans so
  pane animations and layout refreshes cannot move the quota control back to a fallback position.
- Delay the initial quota control until Open Location is resolved instead of briefly rendering at
  the legacy window-relative fallback position after installation or restart.
- Report the actual first accessibility scan in diagnostics, making fallback regressions visible
  instead of replacing them with a second cached lookup.

## [0.1.5] - 2026-08-09

### Fixed

- Keep the quota control exactly 8 points before the native Open Location button whether Codex's
  right pane is open or closed.
- Periodically revalidate cached accessibility anchors so opening, closing, or resizing a pane is
  reflected automatically.
- Render the detail card with Codex-native semantic window and separator colors instead of a
  visual-effect material that appeared unchanged inside the transparent companion window.

### Changed

- Widen the detail card to 300 points so reset and Bank expiry dates remain on one line.
- Label every Bank row as `Bank N到期时间` and use compact relative intervals such as `3d10h`.

## [0.1.4] - 2026-08-09

### Changed

- Match the quota detail card more closely to Codex's native popover material, border, corner
  radius, and theme-aware background.
- Increase the compact quota label size and weight to match nearby native titlebar controls.
- Show live relative intervals after the next reset and every Bank expiry date.
- Wrap long detail values within the existing compact card width instead of truncating them.

## [0.1.3] - 2026-08-09

### Fixed

- Preserve the visible quota control when clicking it activates the external companion, preventing
  the control from briefly hiding before the foreground fallback shows it again.

## [0.1.2] - 2026-08-09

### Changed

- Anchor the single quota control directly to the native Open Location button with an exact
  8-point gap.
- Cache the resolved accessibility element and sample its current frame every 0.1 seconds so pane,
  resize, and window movement cannot change the gap.
- Remove the sidebar/footer presentation state stack, surface classifier, and global event monitors.
- Use a continuous green-to-orange-to-red scale for the compact percentage, hover percentage, and
  progress bar.
- Run the app-server with a dedicated `CodexHome` authorized through the official `codex login`
  flow instead of relying on the user's normal Codex home.
- Select a stable local signing identity when available and apply a deterministic ad-hoc designated
  requirement in CI to reduce Accessibility permission churn.
- Expand the pure Swift suite to 71 tests, including anchor resolution, window matching, runtime
  configuration, color interpolation, layout, transport, and signing behavior.

## [0.1.1] - 2026-08-02

### Fixed

- Keep the usage control permanently in the right titlebar on Codex main surfaces, whether the left
  sidebar is expanded or collapsed.
- Remove the fragile dependency on the expanded sidebar footer/profile anchor.
- Continue hiding the companion on Settings and other completed non-main surfaces.

## [0.1.0] - 2026-08-02

### Added

- Live remaining quota and reset time in the expanded Codex sidebar.
- Adaptive compact quota placement before the right-side titlebar controls when collapsed.
- Theme-aware native hover card with plan, period, Credits, and every Bank entry.
- Automatic hiding on Settings and other completed non-main surfaces.
- Real-time app-server notifications, refresh recovery, stale-data handling, and reset checks.
- External LaunchAgent installation, automatic repair, and one-command uninstall.
- English, Chinese, human, and agent-focused installation documentation.

[0.1.0]: https://github.com/JaceHwang/codex-usage-sidebar/releases/tag/v0.1.0
[0.1.1]: https://github.com/JaceHwang/codex-usage-sidebar/releases/tag/v0.1.1
[0.1.2]: https://github.com/JaceHwang/codex-usage-sidebar/releases/tag/v0.1.2
[0.1.3]: https://github.com/JaceHwang/codex-usage-sidebar/releases/tag/v0.1.3
[0.1.4]: https://github.com/JaceHwang/codex-usage-sidebar/releases/tag/v0.1.4
[0.1.5]: https://github.com/JaceHwang/codex-usage-sidebar/releases/tag/v0.1.5
[0.1.6]: https://github.com/JaceHwang/codex-usage-sidebar/releases/tag/v0.1.6
[0.1.7]: https://github.com/JaceHwang/codex-usage-sidebar/releases/tag/v0.1.7
[0.1.8]: https://github.com/JaceHwang/codex-usage-sidebar/releases/tag/v0.1.8
[0.1.9]: https://github.com/JaceHwang/codex-usage-sidebar/releases/tag/v0.1.9
[0.2.0]: https://github.com/JaceHwang/codex-usage-sidebar/releases/tag/v0.2.0
[0.2.1]: https://github.com/JaceHwang/codex-usage-sidebar/releases/tag/v0.2.1
