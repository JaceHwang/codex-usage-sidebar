# Adaptive Titlebar Placement Design

Date: 2026-08-10
Release: v0.2.3

## Problem

Dragging the Codex right pane left changes the available center-titlebar width continuously. At
some intermediate widths, the old midpoint-pruned accessibility scan missed a native button that
the 164-point quota control could still cover. The existing fallback worked only after space became
fully constrained, leaving an overlap window between the direct-anchor and fallback states.

## Source of truth

The active Codex AX window supplies titlebar geometry. `AXButton` elements may be semantic anchor
candidates. Both `AXButton` and `AXStaticText` frames are occupied geometry. The overlay remains an
external AppKit panel; no Codex bundle, DOM, or application code is modified.

## Placement policy

1. Resolve Open Location as the preferred semantic anchor.
2. Build the exact frame whose trailing edge is eight points before that anchor.
3. If occupied, move left to the nearest complete free frame without crossing a static title.
4. If no complete local frame exists, select the established safe right-side fallback immediately.
5. Re-evaluate at the existing 0.1-second cadence as panes and windows change.

The policy uses complete-frame fit, not the center page width alone. This keeps the gap stable when
possible and makes the transition to fallback deterministic.

## Scan bounds and performance

Horizontal scan bounds include the complete region the indicator could occupy, including space
left of the window midpoint. Vertical bounds stop at the 46-point titlebar, preventing traversal
into sidebars and conversation content. Only items at least eight points high can occupy titlebar
space; this rejects conversation controls that fullscreen clipping collapses into 1-point frames at
the top window edge while retaining real 17-point static titles. In the reproduced layout, the
optimized scan visits 54 elements instead of 769. Frame eligibility is evaluated before label
attributes are read, and rejected clipped branches are not traversed further.

## Cache semantics

Every 0.1-second tick performs a fresh eligible-geometry scan and collision pass. A result with a
numeric edge is resolved. An intentional `fallback` result clears any retained semantic anchor. A
nil-edge fallback is transiently unresolved and may retain the last valid frame for at most 0.75
seconds to avoid flicker during AX-tree refreshes.

## Visual and privacy constraints

The control, hover card, colors, typography, localization, and interactions do not change. Only its
titlebar placement changes. Accessibility labels are used locally for semantic matching; persisted
diagnostics expose sanitized source names, counts, edges, and frames only.

## Acceptance criteria

- No overlap while dragging the right pane through every intermediate width.
- Nearest-free-slot placement keeps the resolved eight-point edge gap.
- Insufficient local space selects the safe right-side fallback without a stale-cache delay.
- Left, right, and bottom pane changes remain responsive.
- Fullscreen with the right pane closed ignores degenerate clipped content and retains the exact
  Open Location anchor.
- Settings and non-main-surface visibility behavior is unchanged.
- Real screenshots document both adaptive states.
