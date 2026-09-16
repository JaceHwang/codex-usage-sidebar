# Codex Usage Sidebar macOS v0.4.0

> Release candidate — not published yet.

This macOS 14+ Apple Silicon feature release adds explicit indicator placement
modes without changing the Windows v0.3.3 release:

- Right-click the titlebar indicator to select Automatic, Free, or Locked.
- Automatic preserves collision-aware titlebar placement.
- Free keeps a per-display manual position and supports deliberate left-button
  dragging; Locked keeps that position while preventing dragging.
- Manual positions are normalized and constrained to the visible screen region
  when display geometry changes.

It also contains the prior cold-start layout and resize-guidance fixes that
were prepared in the unpublished v0.3.6 candidate.

The quota-detail table reserves at least eight rows (256 points) naturally and grows with content up to the screen/height cap. Manual resizing takes precedence, with a two-row minimum.

## Planned assets

- Installer: `codex-usage-sidebar-v0.4.0-macos-arm64.dmg`
- Checksums: `MACOS-V040-SHA256SUMS.txt`
- Provenance: `MACOS-V040-PROVENANCE.json`

The asset can be published only after the `v0.4.0` tag identifies the
same verified commit embedded in the installer payload and recorded in
provenance.

## Current candidate additions (not a published asset)

- Header detail lock, independent from Locked indicator position, plus footer settings for position
  mode, Releases, reload and quit.
- Bank expiry urgency colors: red through three days, orange through seven days, green thereafter.
- Final-frame collision checks, including cached/default positions and actionable titlebar controls.
- Crowding returns to the default position; a button collision there persistently switches to Free.
- Auxiliary AX menu/scroll actions on containers are excluded, fixing immediate false degradation.

See [current features](../CURRENT_FEATURES.md) and [current design](../CURRENT_DESIGN.md).
Release Please generates the `v0.4.0` tag after the version PR is reviewed and merged;
the macOS staged publisher builds and verifies that exact source before publishing immutable assets.
