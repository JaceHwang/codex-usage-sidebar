# Privacy Model

## Data read

- Remaining Codex quota, reset time, plan metadata, Credits, and Bank entries from the local Codex
  `app-server` JSON-RPC stream.
- Codex window geometry, button descriptions, and theme preference for placement and styling.
- Local process and bundle metadata needed to discover the running Codex installation.

## Data written

- Companion application and control script under
  `~/Library/Application Support/CodexUsageSidebar/`.
- A user LaunchAgent at `~/Library/LaunchAgents/com.jace.codex-usage-sidebar.plist`.
- Small local runtime logs and persisted placement state.

## Data not collected

- Account passwords or OAuth tokens
- Conversation text or repository contents
- Browser cookies
- Usage telemetry or analytics
- Remote identifiers beyond what the local Codex app-server already returns for rate limits

## Network behavior

The companion does not add a remote analytics or application server. It communicates with the
Codex app-server executable over local stdio. Any network access performed by that official
component remains governed by Codex itself.

## Accessibility permission

Accessibility is used only to inspect Codex window semantics for placement and surface
classification. The plugin does not synthesize typing, read other applications' accessibility
trees, or bypass the macOS permission prompt.
