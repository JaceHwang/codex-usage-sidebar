# Install with an Agent

This playbook is for a coding agent with terminal access to the target Mac.

## Copy-paste task

```text
Install Codex Usage Sidebar from the public GitHub marketplace.

Requirements:
1. Verify macOS 14+, Apple Silicon, Codex desktop, and the codex CLI.
2. Install JaceHwang/codex-usage-sidebar through the codex plugin marketplace commands.
3. Do not modify, inject into, or re-sign the official Codex application.
4. Explain that a new Codex task is required before the SessionStart hook is available.
5. Authorize the companion's isolated CodexHome with the official codex login command.
6. In the new task, invoke @codex-usage-sidebar to check and repair the installation.
7. Verify the LaunchAgent, status output, isolated login, and accessibility state.
8. If Accessibility is off, open the correct System Settings pane and ask me to approve the switch.
9. Confirm anchor=openLocation, placement=content-header, and cached:true without exposing unrelated
   windows, conversations, or account data.
```

## Deterministic procedure

### 1. Preflight

```bash
test "$(uname -s)" = Darwin
test "$(uname -m)" = arm64
sw_vers -productVersion
codex --version
codex plugin --help
```

Report a failed requirement instead of attempting an unsupported installation.

### 2. Install

```bash
codex plugin marketplace add JaceHwang/codex-usage-sidebar
codex plugin add codex-usage-sidebar@codex-usage-sidebar
codex plugin list
```

Confirm `codex-usage-sidebar@codex-usage-sidebar` is installed and enabled.

### 3. Cross the task boundary

Plugins and skills load when a task starts. Ask the user to create a new Codex task, then invoke:

```text
@codex-usage-sidebar check the installation and repair it if needed
```

### 4. Authorize the isolated Codex home

```bash
plugin_home="$HOME/Library/Application Support/CodexUsageSidebar/CodexHome"
env CODEX_HOME="$plugin_home" codex login
env CODEX_HOME="$plugin_home" codex login status
```

The login flow is interactive and may require the user to finish authorization. Do not copy
`~/.codex/auth.json` into the isolated home.

### 5. Verify runtime and placement

```bash
control="$HOME/Library/Application Support/CodexUsageSidebar/sidebar-control.sh"
test -x "$control"
"$control" status
launchctl print "gui/$(id -u)/com.jace.codex-usage-sidebar"
```

Interpret status conservatively:

- `installed and loaded` confirms the managed runtime is present.
- `accessibility=granted` permits semantic placement checks.
- `accessibility=required` means the user must approve the macOS switch.
- `anchor=openLocation placement=content-header` confirms the intended anchor.
- `cached:true` confirms the 0.1-second position loop is using the cached AX element.

Accessibility is a macOS security permission. Never bypass it or claim it is granted before the OS
reports that state.

### 6. Repair after an update

```bash
"$HOME/Library/Application Support/CodexUsageSidebar/sidebar-control.sh" repair
```

The companion rediscovers the current Codex bundle and its `app-server`; no official application
patch is required.

### 7. Report evidence

Return the plugin version, login status, companion status, LaunchAgent state, Accessibility state,
anchor source, and whether the visible control keeps an 8-point gap from Open Location while panes
and window size change. Crop screenshots to the relevant titlebar area.
