# Troubleshooting

## No quota control appears

1. Open Codex desktop and bring its main window to the foreground.
2. Start a new Codex task so the `SessionStart` hook runs.
3. Verify the companion:

   ```bash
   "$HOME/Library/Application Support/CodexUsageSidebar/sidebar-control.sh" status
   ```

4. Repair if the service is missing or stale:

   ```bash
   "$HOME/Library/Application Support/CodexUsageSidebar/sidebar-control.sh" repair
   ```

If status reports `hidden:no-snapshot`, verify the isolated login described next.

## Isolated Codex home is not logged in

The companion does not use the normal `~/.codex` credentials. Authorize its private home:

```bash
plugin_home="$HOME/Library/Application Support/CodexUsageSidebar/CodexHome"
env CODEX_HOME="$plugin_home" codex login
env CODEX_HOME="$plugin_home" codex login status
```

Then repair the companion or wait for its app-server client to reconnect.

## Status says `accessibility=required`

Enable **Codex Usage Sidebar** in
`System Settings -> Privacy & Security -> Accessibility`, then run repair. Do not enable only Codex;
the separately installed companion needs its own entry.

The stable designated requirement reduces permission churn, but macOS can still request approval
after signing or security-policy changes.

## The gap is not fixed beside Open Location

Run status and inspect the anchor fields:

```text
anchor=openLocation placement=content-header anchor_scan=...cached:true,source:openLocation
```

- `openLocation` is the intended exact 8-point placement.
- `labeledControl` means the named button was unavailable and another header control was used.
- `rightPaneBoundary` means only the pane edge was resolved.
- `fallback` means the companion used a safe in-window position.

Bring the Codex window to the foreground, confirm Accessibility, and run repair. If the fallback
persists, include sanitized status output and the Codex build number in a bug report.

## Data looks old

The indicator dims after two minutes and hides after five. Confirm the isolated login is active and
Codex is online, then bring Codex to the foreground. The client automatically recovers from a
stalled stream; repair forces an immediate clean restart.

Logs are stored at:

```text
~/Library/Application Support/CodexUsageSidebar/Data/sidebar.log
~/Library/Application Support/CodexUsageSidebar/Data/sidebar-error.log
```

Remove credentials and account identifiers before sharing log excerpts.

## Update or reset

Normal update:

```bash
codex plugin marketplace upgrade codex-usage-sidebar
codex plugin add codex-usage-sidebar@codex-usage-sidebar
```

Full reset:

```bash
"$HOME/Library/Application Support/CodexUsageSidebar/sidebar-control.sh" uninstall
codex plugin marketplace upgrade codex-usage-sidebar
codex plugin add codex-usage-sidebar@codex-usage-sidebar
```

Start a new Codex task afterward.

## Reporting a bug

Use the repository bug form. Include macOS version, Codex build, plugin version, sanitized status
output, the relevant log excerpt, and exact reproduction steps. Crop screenshots to the affected
titlebar area; never attach a full desktop containing unrelated projects or conversations.
