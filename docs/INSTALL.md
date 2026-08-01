# Installation and Operations

## Requirements

- macOS 14 or later
- Apple Silicon Mac (`arm64`)
- Codex desktop app installed and running
- `codex` CLI with plugin support

Check the CLI first:

```bash
codex --version
codex plugin --help
```

## Install

Add this repository as a Git marketplace, then install the plugin:

```bash
codex plugin marketplace add Byctor/codex-usage-sidebar
codex plugin add codex-usage-sidebar@codex-usage-sidebar
```

Start a new Codex task. The plugin's `SessionStart` hook copies the signed companion to:

```text
~/Library/Application Support/CodexUsageSidebar/Codex Usage Sidebar.app
```

and loads:

```text
~/Library/LaunchAgents/com.jace.codex-usage-sidebar.plist
```

Check it:

```bash
"$HOME/Library/Application Support/CodexUsageSidebar/sidebar-control.sh" status
```

Expected final line:

```text
installed and loaded: .../Codex Usage Sidebar.app
```

## Enable precise surface detection

Open `System Settings → Privacy & Security → Accessibility` and enable
`Codex Usage Sidebar.app`. macOS may require Touch ID or an administrator password.

This permission lets the companion distinguish the main surface from Settings and align to Codex's
semantic controls. Without it, the companion preserves the last synchronized placement instead of
guessing from incomplete data.

Official Codex app upgrades do not normally change this permission because the companion is
installed separately. The public companion is currently ad-hoc signed; a plugin update that replaces
its executable may change its macOS code identity and require Accessibility approval again. The
installer verifies the signature but does not bypass macOS or claim Developer ID notarization.

After changing the switch, repair once:

```bash
"$HOME/Library/Application Support/CodexUsageSidebar/sidebar-control.sh" repair
```

## Update

```bash
codex plugin marketplace upgrade codex-usage-sidebar
codex plugin add codex-usage-sidebar@codex-usage-sidebar
```

Then start a new Codex task. The hook atomically replaces the old payload. Official Codex app
updates do not require reinstalling this plugin; if the indicator is missing, run the repair command.

## Repair and status

```bash
"$HOME/Library/Application Support/CodexUsageSidebar/sidebar-control.sh" status
"$HOME/Library/Application Support/CodexUsageSidebar/sidebar-control.sh" repair
```

Inside a new Codex task you can also ask:

```text
@codex-usage-sidebar check and repair the usage sidebar
```

## Uninstall

Stop and remove the companion first:

```bash
"$HOME/Library/Application Support/CodexUsageSidebar/sidebar-control.sh" uninstall
```

Then remove the plugin and marketplace:

```bash
codex plugin remove codex-usage-sidebar@codex-usage-sidebar
codex plugin marketplace remove codex-usage-sidebar
```

The uninstall command only removes the companion's exact Application Support directory and user
LaunchAgent. It does not touch the official Codex app.
