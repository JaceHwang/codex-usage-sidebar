# Indicator Position Modes Design

## Goal

Give the persistent Codex quota indicator three explicit placement modes without
changing its existing quota-card interaction:

- **Automatic attach** keeps the existing title-bar anchor behaviour.
- **Free move** keeps the indicator at a manually selected screen position and
  allows a deliberate left-button drag.
- **Locked** keeps the same manual position but disallows dragging.

The scope is macOS only. Windows stays unchanged until it receives a separate
parity implementation.

## Approved interaction and visual direction

The user selected concept **C**. A right-click on the header indicator opens a
small, native AppKit settings popover:

- heading: `位置模式` / localized equivalent;
- one compact segmented choice: `自动`, `自由`, `锁定`;
- a thin divider plus one muted sentence explaining the selected mode;
- the panel inherits the current light or dark macOS appearance, with no custom
  web-style controls.

The panel dismisses on outside click, Escape, or immediately after changing the
mode. Right-click must never toggle the quota detail card.

## Behaviour

### Automatic attach

`automatic` uses the existing `ContentHeaderLocator` and `OverlayLayout`
calculation on every layout tick. It follows the host title bar, side-pane
changes, window movement, and the existing fallback anchor exactly as today.

### Free move

`free` starts from the indicator's current automatic frame when selected. A
primary-button drag that exceeds a 4-point threshold moves the indicator. A
normal click remains a normal quota-card toggle. Moving the Codex window or its
sidebars does not reposition a free indicator.

### Locked

`locked` preserves the currently stored manual frame but never enters the drag
path. Its normal left click continues to toggle the quota card.

### Persistence and display safety

- The selected mode is global.
- Manual frames are saved separately for each display, using a stable display
  identity where available.
- Each frame is stored as a normalized origin inside that display's
  `visibleFrame`, not as raw pixels. This keeps it reasonable when the
  resolution, scale, Dock, or screen arrangement changes.
- Before display, the resolved manual frame is clamped fully within the current
  display's `visibleFrame`.
- Switching from automatic to either manual mode captures the currently shown
  frame for the display; Free and Locked share that stored position.
- Switching back to Automatic immediately returns the indicator to its normal
  title-bar placement.

The quota detail card continues to anchor to the actual indicator frame in all
three modes and retains its existing clamping/hover/pin behaviour.

## Localization and accessibility

Add Simplified Chinese, Traditional Chinese, and English labels for the panel,
each mode, and its explanatory copy. The segmented control and the indicator's
right-click entry point expose clear accessibility labels. Other Codex UI
languages continue to resolve through the existing English fallback.

## Non-goals

- No Windows implementation in this change.
- No new settings page, telemetry, account data, or quota API behaviour.
- No change to default placement: a fresh install remains in Automatic mode.

## Acceptance criteria

1. Right-click displays concept-C controls and selecting a mode persists it.
2. Automatic mode follows the Codex title bar exactly as before.
3. Free mode can be moved smoothly with a deliberate primary-button drag;
   clicking still opens/pins the quota card.
4. Locked mode cannot be dragged and still opens/pins the quota card.
5. A manual position persists independently per display, survives restart, and
   is clamped to the visible screen after display geometry changes.
6. Existing settings-page hiding, language fallback, dynamic titlebar placement,
   detail-card hover, and first-open layout guarantees remain intact.
