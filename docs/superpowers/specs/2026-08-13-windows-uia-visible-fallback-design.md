# Windows UIA Flat-Title and Visible Fallback Design

Date: 2026-08-13
Target: Codex Usage Sidebar v0.3.0 on Windows 11 x64

## Problem

Codex build `151.0.7922.76` now exposes the task icon, task title, and title action as direct children of the content toolbar instead of wrapping them in the previously measured title group. The installed overlay host and quota app-server remain healthy, but the strict selector rejects this topology and hides the overlay.

## Exact UIA Variant

Keep the existing wrapped-title selector and add one measured flat-title variant for the same build. The flat variant requires exactly one title text group, one leading composer icon before it, and one rounded title action aligned after it. The Open Location button, caption buttons, toolbar, right pane, and right-toolbar fallback retain their existing identity and geometry checks. Missing, duplicate, ambiguous, off-host, or unknown-build structures remain rejected.

## Visible Fallback

When exact UIA resolution fails, the overlay may use a host-relative fallback only when all of the following hold:

- the window was already authenticated as the protected Microsoft Store Codex host;
- the file build is exactly `151.0.7922.76`;
- host bounds and DPI are finite and large enough for the indicator;
- a fresh quota snapshot exists.

The fallback centers the indicator horizontally in the authenticated Codex window and places it at the measured content-toolbar height using physical pixels derived from the current host bounds and DPI. It remains owned by the Codex HWND, non-activating, and recalculates on every reconciliation tick, so it follows moves, resizes, and DPI changes. Unknown builds, invalid host bounds, missing snapshots, and non-Codex windows remain hidden.

## Verification

- Selector fixture tests cover the measured flat topology plus missing and duplicate title children.
- Coordinator tests cover known-build fallback and unknown-build rejection.
- Full Windows tests, formatting, build, payload integrity, and freeze gates run before installation.
- The rebuilt nonpublishable device-test payload is installed for the current user, then verified with a default-redacted UIA report and a local screenshot of the actual Codex titlebar and hover detail.
- No public setup or release asset is published until the full real-device matrix remains complete and provenance-bound.
