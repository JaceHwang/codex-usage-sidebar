# Troubleshooting

## The plugin is installed but no quota appears

1. Open Codex desktop and leave it on the normal main surface.
2. Start a new Codex task so the `SessionStart` hook runs.
3. Check the runtime:

   ```bash
   "$HOME/Library/Application Support/CodexUsageSidebar/sidebar-control.sh" status
   ```

4. Repair if needed:

   ```bash
   "$HOME/Library/Application Support/CodexUsageSidebar/sidebar-control.sh" repair
   ```

## Status says `accessibility=required`

Enable `Codex Usage Sidebar.app` in
`System Settings → Privacy & Security → Accessibility`, then run repair. A rebuilt development
binary has a new ad-hoc signature and may need this permission again; unchanged release payloads do
not change when Codex itself upgrades.

## The quota remains visible in Settings

This means the long-running companion cannot complete the semantic surface scan. Confirm the exact
installed `Codex Usage Sidebar.app` is enabled in Accessibility, repair, and reopen Settings.

## The titlebar quota is in the fallback position

The companion could not resolve the current right-side titlebar controls. It uses a safe trailing
fallback inside the window. Include sanitized `status` output and Codex build number in a bug report.

## Data looks old

The indicator dims after two minutes and hides after five. Confirm Codex is online, return it to the
foreground, and run repair. The app-server client automatically restarts after a stalled stream.

## Reset everything

```bash
"$HOME/Library/Application Support/CodexUsageSidebar/sidebar-control.sh" uninstall
codex plugin marketplace upgrade codex-usage-sidebar
codex plugin add codex-usage-sidebar@codex-usage-sidebar
```

Start a new Codex task afterward.

## Reporting a bug

Use the repository bug form. Include macOS version, Codex build, plugin version, sanitized status
output, and exact reproduction steps. Crop screenshots to the relevant UI; never attach a full
desktop containing unrelated projects or conversations.
