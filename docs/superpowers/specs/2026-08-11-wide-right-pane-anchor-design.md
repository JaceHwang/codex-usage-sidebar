# Wide Right-Pane Anchor Fix Design

Date: 2026-08-11
Release baseline: v0.2.3

## Problem

When the Codex right pane becomes wider than 520 points, Open Location can move left of the
whole-window midpoint while still leaving more than 164 points of free titlebar space before it.
The current resolver rejects both that semantic anchor and the wide pane boundary, returns
`fallback`, and places the quota control over the right pane.

## Visual decision

The user-provided screenshot is the source of truth. The existing native styling, 164-point
control width, hover behavior, localization, and eight-point Open Location gap remain unchanged.
No concept images are needed because this is a responsive placement correction, not a new visual
direction.

## Placement policy

1. Eligible Open Location controls are semantic anchors regardless of which side of the
   whole-window midpoint contains their center.
2. The resolver constructs the exact 164-point quota frame ending eight points before Open
   Location and runs the existing collision pass against every eligible titlebar item.
3. Static title text remains a hard barrier; the resolver must not cover it merely because a
   semantic anchor exists farther right.
4. Pane-boundary inference remains a secondary fallback. A right-anchored structural pane may be
   wider than 520 points as long as it is not the full-width content surface.
5. The established right-side fallback is used only when no complete collision-free local frame
   exists.
6. Descendant scanning starts with the existing narrow right-side band, then expands only to the
   resolved indicator frame's left edge minus the collision gap when a semantic anchor or
   collision shift needs it. Each
   pass retains vertical pruning and element/depth limits; it stops on numeric fallback, once the
   resolved range is covered, or after a bounded number of passes. Exhausting that bound while
   more scanning is required produces an intentional numeric fallback.
7. A local anchor is accepted only when the realized, clamped indicator still ends exactly eight
   points before its selected control and does not overlap that control.
8. Structural pane inference accepts right-anchored panes up to 60% of window width, rejecting
   wider outer content surfaces even when a real nested pane is present.

## Scope and safety

The change is confined to `ContentHeaderAnchorResolver`, `ContentHeaderLocator`, and their tests.
It does not change quota
data collection, UI appearance, versions, installer behavior, Accessibility permissions, or Codex
application files. Runtime placement continues to refresh every 0.1 seconds.

## Acceptance criteria

- The screenshot layout resolves to Open Location instead of `fallback`.
- The quota frame fits in the visible center-titlebar gap with an exact eight-point trailing gap.
- Existing collision, static-title, fullscreen, pane, and fallback regressions remain green.
- A local companion build is installed and its runtime diagnostic reports a resolved local anchor
  in the reproduced layout.
- The packaged plugin and macOS installer pass their existing validation gates before publication.
