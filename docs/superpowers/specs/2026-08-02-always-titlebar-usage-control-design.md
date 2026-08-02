# Always-Visible Titlebar Usage Control Design

Date: 2026-08-02

## Objective

On every confirmed Codex main surface, render the usage control in the right titlebar group whether
the left sidebar is expanded or collapsed. Keep the existing behavior that hides the control on
Settings and other completed non-main surfaces.

## Root cause

The current renderer treats sidebar visibility as placement state. When the sidebar is expanded,
the accessibility probe resolves `.sidebar`, and `RuntimeCoordinator` requires a profile-row anchor
before it can render. The live diagnostic reproduced that route (`placement=sidebar`) while the user
observed no control. A missing or stale footer anchor therefore hides otherwise valid usage data.

## Selected design

Separate surface classification from visual placement:

- `SidebarVisibilityLocator` continues to identify a confirmed main surface. Its observed
  `.sidebar` or `.titlebar` value is classification evidence only.
- `OverlayPresentationPolicy` normalizes every resolved main-surface probe to
  `.show(.titlebar)`.
- `RuntimeCoordinator` therefore always uses `OverlayLayout.titlebarIndicatorFrame`, including when
  a persisted sidebar state exists or a probe is temporarily skipped/unavailable after a prior
  confirmed main surface.
- A completed unresolved renderer surface still returns `.hide`, preserving Settings-page hiding.
- Sidebar mouse and Command-B events may continue to trigger reconciliation, but they cannot move
  the control back to the footer.

This keeps one control, one hover card, and one positioning path. It removes the profile-row anchor
as a rendering dependency without weakening the existing conservative hide policy.

## User-visible behavior

- Sidebar expanded: usage control remains in the right titlebar before the native icon group.
- Sidebar collapsed: usage control remains in the same right-titlebar position.
- Sidebar toggled while Codex is foreground: control is re-evaluated but does not move to the footer.
- Settings or another completed non-main surface: control hides.
- Hover details, theme behavior, quota refresh, Bank rows, and stale-data behavior are unchanged.

## Testing

Add a regression test proving that both `.resolved(.sidebar)` and `.resolved(.titlebar)` produce
`.show(.titlebar)`. Keep the unresolved-surface hide test and skipped/unavailable preservation tests.
Run the focused policy suite, the full Swift suite, install lifecycle tests, live app-server probe,
bundle signature checks, and visual verification with both sidebar states.

## Release

Build and install locally first. After verification, publish a patch release with a CI-built
companion and refreshed provenance so marketplace users receive the exact tested binary.
