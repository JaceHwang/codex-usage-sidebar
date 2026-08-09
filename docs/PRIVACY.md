# Privacy Model

## Data read

- Remaining Codex quota, reset time, plan metadata, Credits, and every Bank entry from the local
  Codex `app-server` JSON-RPC stream.
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
- Runtime data and local logs under the `Data` subdirectory.
- One user LaunchAgent at `~/Library/LaunchAgents/com.jace.codex-usage-sidebar.plist`.

## Data not collected

- Conversation text or repository contents
- Browser cookies or data from other applications
- Normal Codex-home credentials
- Keyboard or global mouse events
- Usage telemetry, remote analytics, or advertising identifiers

## Network behavior

The companion adds no analytics service or application server. It communicates with the official
Codex `app-server` executable over local stdio. Network access performed by that component for
authenticated quota data remains governed by Codex itself.

## Accessibility permission

Accessibility is used only to inspect the active Codex window and identify the native Open Location
control by its title, description, help text, or identifier. The companion reads geometry to place
its overlay. It does not synthesize typing or clicks, inspect another application's accessibility
tree, or bypass the macOS permission prompt.
