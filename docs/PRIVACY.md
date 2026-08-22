# Privacy Model

## Data read

- Remaining Codex quota, reset time, plan metadata, Credits, every Bank entry, seven-day Token usage,
  and account display identity from the local Codex `app-server` JSON-RPC stream.
- Codex window geometry and named-control accessibility labels and frames needed for placement.
- Local process and bundle metadata needed to discover the running Codex installation.
- Local Codex theme preference used to match light and dark appearance.

## Authentication

The companion launches `codex app-server` with an isolated home at:

```text
~/Library/Application Support/CodexUsageSidebar/CodexHome
```

Credentials in that directory are created only through the official `codex login` flow. The plugin
does not copy or read the normal `~/.codex/auth.json` file.

## Data written

- Companion application and control script under
  `~/Library/Application Support/CodexUsageSidebar/`.
- Isolated Codex authentication and configuration under its `CodexHome` subdirectory.
- Runtime data and local logs under the `Data` subdirectory. The sanitized runtime-state file
  contains only the companion PID, bundle version, timestamp, visibility, anchor source, and overlay
  geometry; it contains no quota values, account identifiers, or conversation content.
- One user LaunchAgent at `~/Library/LaunchAgents/com.jace.codex-usage-sidebar.plist`.

## Data not collected

- Conversation text or repository contents
- Tibo X content, X API data, prediction data, or browser scraping
- Browser cookies or data from other applications
- Normal Codex-home credentials
- Keyboard or global mouse events
- Usage telemetry, remote analytics, or advertising identifiers

## Network behavior

The companion adds no analytics service or application server. It communicates with the official
Codex `app-server` executable over local stdio. Network access performed by that component for
authenticated quota data remains governed by Codex itself.

## Accessibility permission

Accessibility is used only for placement in the active Codex window. The companion reads labels
and frames from eligible buttons/static text in the 46-point titlebar band to identify a preferred
semantic anchor and avoid meaningfully visible occupied geometry. It also reads structural
`AXGroup` frames in relevant accessibility branches for pane-boundary detection, but never reads
labels or text from those groups. Degenerate content clipped to the fullscreen top edge is rejected
by geometry before any label attribute is read, and its descendants are pruned from traversal.
Eligible titlebar labels remain in memory; managed diagnostics contain only the sanitized anchor
source, scan counts, edge, and indicator frame. It does not read conversation bodies, synthesize
typing or clicks, inspect another application's accessibility tree, or bypass the macOS permission
prompt.
