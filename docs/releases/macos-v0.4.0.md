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

The quota-detail table now opens with a stable eight-row (256-point) viewport. Sparse data no
longer collapses the card; user resizing still takes precedence, with a two-row minimum and
screen-safe placement cap.

## Planned assets

- Installer: `codex-usage-sidebar-macos-arm64-v0.4.0.dmg`
- Checksums: `MACOS-V040-SHA256SUMS.txt`
- Provenance: `MACOS-V040-PROVENANCE.json`

The asset can be published only after the `macos-v0.4.0` tag identifies the
same verified commit embedded in the installer payload and recorded in
provenance.
