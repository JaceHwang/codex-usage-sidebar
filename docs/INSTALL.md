# Installation and Operations

## Requirements

- macOS 14 or later
- Apple Silicon Mac (`arm64`)
- Codex desktop app installed and running
- `codex` CLI with plugin support

Verify the CLI before installing:

```bash
codex --version
codex plugin --help
```

## Install from the marketplace

```bash
codex plugin marketplace add JaceHwang/codex-usage-sidebar
codex plugin add codex-usage-sidebar@codex-usage-sidebar
```

Start a **new Codex task**. Codex discovers plugin skills and runs `SessionStart` hooks at a task
boundary, as described by the [official Codex plugin workflow](https://developers.openai.com/learn/developers-codex-plugin/).
The hook installs the companion at:

```text
~/Library/Application Support/CodexUsageSidebar/Codex Usage Sidebar.app
```

and loads the user LaunchAgent at:

```text
~/Library/LaunchAgents/com.jace.codex-usage-sidebar.plist
```

## Authorize the isolated Codex home

The companion intentionally uses a separate `CodexHome`. It does not copy credentials from the
normal `~/.codex` directory. Authorize this home once with the official CLI:

```bash
plugin_home="$HOME/Library/Application Support/CodexUsageSidebar/CodexHome"
env CODEX_HOME="$plugin_home" codex login
env CODEX_HOME="$plugin_home" codex login status
```

This authorization survives companion restarts and normal Codex app upgrades.

## Grant Accessibility

Open `System Settings -> Privacy & Security -> Accessibility` and enable
**Codex Usage Sidebar**. macOS may require Touch ID or an administrator password.

Accessibility lets the companion identify native titlebar controls and static titles, then choose
a collision-free frame. It reads labels and frames only from eligible titlebar buttons/static text,
plus unlabeled structural group frames in the relevant region for pane-boundary detection. It does
not click, type, or read conversation content.

The release build uses a stable designated requirement to reduce permission churn. macOS remains
the authority and can request approval again after a security-policy or signing change.

Repair once after changing the switch:

```bash
"$HOME/Library/Application Support/CodexUsageSidebar/sidebar-control.sh" repair
```

## Verify

```bash
"$HOME/Library/Application Support/CodexUsageSidebar/sidebar-control.sh" status
```

A healthy adaptive-positioning result is read from the actual managed process and includes:

```text
pid=12345 version=0.2.3 runtime=shown placement=content-header anchor=labeledControl
language=simplifiedChinese language_source=process
indicator=654,1003,164,46 ... cached:false,source:labeledControl,edge:826
installed and loaded: .../Codex Usage Sidebar.app
```

`openLocation`, `labeledControl`, and `rightPaneBoundary` are valid resolved sources. For those
sources, an indicator frame `x,y,width,height` satisfies `x + width = edge - 8`. A `fallback` with
a numeric edge is also healthy: it is the deliberate safe right-side position used when no full
local slot remains. v0.2.3 normally reports `cached:false` because every placement tick re-scans
eligible titlebar geometry; the version must match the badge beside the hover-card title. See
[Troubleshooting](TROUBLESHOOTING.md).

The language fields report the effective mapped UI language and how it was obtained. `process` is
the preferred steady-state result because it reflects the language Codex is actually displaying,
including the final result of the Auto setting. `preferences` and `system` are startup fallbacks.

## Update

```bash
codex plugin marketplace upgrade codex-usage-sidebar
codex plugin add codex-usage-sidebar@codex-usage-sidebar
```

Start a new Codex task. The hook atomically replaces the old payload. Updating the official Codex
app does not normally require reinstalling this plugin.

During replacement, the installer compares a source-payload fingerprint and re-signs the copied
app with the stable local identity when available. This prevents a routine plugin reinstall from
silently changing the Accessibility identity of the already-authorized companion.

## Repair

```bash
"$HOME/Library/Application Support/CodexUsageSidebar/sidebar-control.sh" repair
```

Inside a new Codex task, the plugin skill can perform the same check:

```text
@codex-usage-sidebar check and repair the usage sidebar
```

## Uninstall

Remove the companion first:

```bash
"$HOME/Library/Application Support/CodexUsageSidebar/sidebar-control.sh" uninstall
```

Then remove the plugin and marketplace:

```bash
codex plugin remove codex-usage-sidebar@codex-usage-sidebar
codex plugin marketplace remove codex-usage-sidebar
```

Uninstall removes only the companion's exact Application Support directory and user LaunchAgent.
It does not modify the official Codex app.
