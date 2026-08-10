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
9. Resize the right pane and confirm collision-free adaptive placement: a resolved local source
   keeps an 8-point edge gap, while insufficient space selects the safe right-side fallback. Do not
   expose unrelated windows, conversations, or account data.
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
- `placement=content-header` with `openLocation`, `labeledControl`, or `rightPaneBoundary` confirms
  a resolved collision-free local placement.
- `fallback` with a numeric edge confirms the intentional safe right-side placement used when no
  complete local slot remains; it is not a failure.
- `cached:false` is the expected v0.2.3 steady state because every 0.1-second tick re-scans eligible
  titlebar geometry for collisions.
- `pid=<LaunchAgent PID>` confirms status came from the managed process rather than a standalone
  diagnostic invocation.
- `version=<version>` must match the visible badge beside the hover-card title.
- For a resolved non-fallback source with `indicator=x,y,width,height` and `edge=n`, `x + width`
  must equal `n - 8`.

Accessibility is a macOS security permission. Never bypass it or claim it is granted before the OS
reports that state.

### 6. Repair after an update

```bash
"$HOME/Library/Application Support/CodexUsageSidebar/sidebar-control.sh" repair
```

The companion rediscovers the current Codex bundle and its `app-server`; no official application
patch is required. Repair also verifies the source fingerprint, atomically replaces stale payloads,
and preserves the stable local signing identity when available.

### 7. Report evidence

Return the plugin version, login status, companion status, LaunchAgent state, Accessibility state,
anchor source, and whether the control avoids native controls while the right pane is dragged
through intermediate widths. Confirm both the nearest-free-slot and safe-right-fallback states.
Crop screenshots to the relevant titlebar area.
