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

## Install with the graphical installer

1. Download [`codex-usage-sidebar-v0.2.3-macos-arm64.dmg`](https://github.com/JaceHwang/codex-usage-sidebar/releases/download/v0.2.3/codex-usage-sidebar-v0.2.3-macos-arm64.dmg) from the v0.2.3 release **Assets**.
2. Open the DMG, then open **Codex Usage Sidebar Installer**.
3. The raw asset is not notarized. If macOS blocks it, right-click the installer in Finder and choose Open.
4. Click **Install**, complete the isolated Codex login when prompted, and enable Accessibility.
5. Click **Verify** in the installer after granting Accessibility.

The installer embeds the already-promoted v0.2.3 marketplace payload and places the companion and
LaunchAgent in the same locations used by the marketplace hook. It does not modify the Codex app.

## Advanced: install from the marketplace

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

For the graphical installer, download the newer DMG from that release's **Assets**, open it, and
click **Install** again. It replaces the managed payload atomically; repeat the guided login or
Accessibility steps only if the installer reports they need attention.

For a manual marketplace installation:

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

Reopen the graphical installer and click **Install** to re-copy its embedded payload, then click
**Verify**. If the companion is already installed, the command below performs the same lifecycle
repair without downloading the DMG again:

```bash
"$HOME/Library/Application Support/CodexUsageSidebar/sidebar-control.sh" repair
```

Inside a new Codex task, the plugin skill can perform the same check:

```text
@codex-usage-sidebar check and repair the usage sidebar
```

## Uninstall

The graphical installer is only a launcher: ejecting its DMG does not remove the installed
companion. Use the managed companion's uninstall command:

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
