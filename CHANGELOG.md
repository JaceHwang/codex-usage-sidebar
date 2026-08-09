# Changelog

All notable changes to this project are documented here. The project follows
[Semantic Versioning](https://semver.org/).

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
