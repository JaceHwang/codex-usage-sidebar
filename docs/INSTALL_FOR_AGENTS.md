# Install with an Agent

This guide is written for Codex and other coding agents. A human can paste the prompt below into an
agent with terminal access on the target Mac.

## Copy-paste task

```text
Install Codex Usage Sidebar from the public GitHub marketplace.

Requirements:
1. Verify macOS 14+, Apple Silicon, Codex desktop, and the codex CLI.
2. Run:
   codex plugin marketplace add Byctor/codex-usage-sidebar
   codex plugin add codex-usage-sidebar@codex-usage-sidebar
3. Do not modify, inject into, or re-sign /Applications/ChatGPT.app.
4. Explain that a new Codex task is required before the SessionStart hook is available.
5. In the new task, invoke @codex-usage-sidebar to check/repair it.
6. Verify the LaunchAgent is loaded and report the exact status output.
7. If macOS Accessibility is off, open the correct System Settings pane and ask me to approve the
   switch; do not claim it is enabled until the OS reports it.
8. Leave Codex on its normal main surface with the sidebar expanded.
```

## Deterministic agent procedure

### 1. Preflight

```bash
test "$(uname -s)" = Darwin
test "$(uname -m)" = arm64
sw_vers -productVersion
codex --version
codex plugin --help
```

Stop and report the failed requirement instead of attempting an unsupported installation.

### 2. Install marketplace and plugin

```bash
codex plugin marketplace add Byctor/codex-usage-sidebar
codex plugin add codex-usage-sidebar@codex-usage-sidebar
codex plugin list
```

Confirm the list contains `codex-usage-sidebar@codex-usage-sidebar` with `installed, enabled`.

### 3. Cross the task boundary

Plugins and skills are loaded at task start. Ask the user to start a new Codex task, then invoke:

```text
@codex-usage-sidebar check the installation and repair it if needed
```

### 4. Verify runtime

```bash
control="$HOME/Library/Application Support/CodexUsageSidebar/sidebar-control.sh"
test -x "$control"
"$control" status
launchctl print "gui/$(id -u)/com.jace.codex-usage-sidebar"
```

The agent must distinguish these states:

- `installed and loaded`: runtime is present.
- `accessibility=granted`: semantic positioning and Settings hiding can be verified.
- `accessibility=required`: open the Accessibility pane and ask for user approval at the switch.

Accessibility is a macOS security permission. An agent must not bypass it or silently claim success.

### 5. Repair after an official Codex update

```bash
"$HOME/Library/Application Support/CodexUsageSidebar/sidebar-control.sh" repair
```

No application patching is required. The companion rediscovers the current Codex bundle and local
app-server on every session.

### 6. Report evidence

Return the plugin version, status output, LaunchAgent state, Accessibility state, and whether the
indicator appears on the expanded main surface. Do not expose unrelated window contents or account
data in screenshots.
