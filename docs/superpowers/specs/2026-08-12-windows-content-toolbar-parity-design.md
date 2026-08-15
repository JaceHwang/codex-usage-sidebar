# Windows Content Toolbar Parity Design

Date: 2026-08-12
Target: Codex Usage Sidebar v0.3.0-beta.1 on Windows 11 AMD64/x64
Visual baseline: macOS v0.2.3

## Problem

The current Windows device payload validates only the native caption-button container and therefore
places the quota indicator in the outer Windows caption. It can disappear during UIA cache refreshes,
does not remain attached to the content toolbar while the Codex window changes size, and its detail
card compresses the version badge compared with the macOS v0.2.3 screenshots.

## Accepted Behavior

1. The indicator belongs to the active task's center content toolbar, immediately left of Codex's
   semantic Open Location control. Its physical right edge is the control's physical left edge minus
   an 8-logical-pixel DPI-scaled gap.
2. The Windows caption-button container is never a visible placement fallback. It may remain part of
   host identity validation, but it cannot supply the quota anchor.
3. The build-gated selector accepts only a newly captured, default-redacted UIA structure for Codex
   build `151.0.7922.76`. Unknown, incomplete, ambiguous, off-host, or unsafe structures hide the
   overlay rather than guessing a coordinate.
4. Host geometry and the content-toolbar anchor are revalidated every 100 milliseconds. Window move,
   resize, maximize, restore, and pane layout changes reposition the overlay in physical pixels.
5. A transient incomplete scan may retain the last valid placement for at most 750 milliseconds when
   the host handle, build, DPI, and current host geometry still make that frame safe. Once that interval
   expires, or when identity/safety changes, the overlay hides.
6. The indicator uses the macOS v0.2.3 logical size (`164 x 46`) and remains no-activate.
7. The detail card remains approximately 300 logical pixels wide. Its header uses the macOS order and
   spacing: localized title, blue outlined `v0.3.0-beta.1` badge immediately after the title, remaining
   percentage aligned right, then the quota progress bar and divider. The badge must not be squeezed
   into character-by-character wrapping.
8. Existing quota rows, languages, themes, color interpolation, hover/pin behavior, snapshot freshness,
   official Codex runtime isolation, and fail-hidden security boundaries remain unchanged unless the
   visual baseline explicitly requires sizing or spacing changes.

## Evidence and Privacy

The existing fixture contains only the outer Windows caption controls and cannot authorize the new
placement. Before enabling the production selector, capture a new default-redacted report in the
disposable Codex task. Use control type, automation ID, class, depth, geometry, name length, and a
one-way token only; do not persist visible text. The committed fixture must contain no account name,
conversation text, repository path, prompt, notification, or raw Open Location label.

## Testing and Delivery

TDD covers semantic content-toolbar selection, ambiguity and incomplete-tree rejection, physical DPI
placement, resize/reposition behavior, 750-millisecond stabilization, macOS indicator dimensions, and
version badge layout. Real-device verification must exercise restored and resized Codex windows,
hover/detail display, no activation, and unknown-structure hiding. The installed payload remains
`status=device-test`, `realDeviceValidated=false`, and `publishableInstaller=false`; no setup or release
asset is created. macOS v0.2.3 sources and assets are not modified.
