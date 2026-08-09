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

If a locally verified layout moves only after plugin reinstall, compare the visible version badge
with `version=` from status and check that status reports the active LaunchAgent PID. Repair copies
and re-signs the payload with the stable local identity; do not re-sign the official Codex app.

## The gap is not fixed beside Open Location

Run status and inspect the anchor fields:

```text
anchor=openLocation placement=content-header anchor_scan=...cached:true,source:openLocation
```

- `openLocation` is the intended exact 8-point placement.
- `labeledControl` means the named button was unavailable and another header control was used.
- `rightPaneBoundary` means only the pane edge was resolved.
- `fallback` means the companion used a safe in-window position.

For `indicator=x,y,width,height` and `edge=n`, the intended geometry satisfies
`x + width = n - 8`. Bring the Codex window to the foreground, confirm Accessibility, and run
repair. If fallback persists, include sanitized status output, the visible version badge, and the
Codex build number in a bug report.

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

## The plugin language does not match Codex

Run status and inspect the sanitized language fields:

```text
language=traditionalChinese language_source=process
```

The companion follows Codex's effective displayed locale rather than maintaining a separate
language selector. `process` is authoritative while Codex is running; `preferences` and `system`
are startup fallbacks. Simplified Chinese, Traditional Chinese, and English map directly, while
every other locale displays English.

After changing Codex's language setting, allow up to one second for a running renderer change. If
Codex itself still shows the previous language, restart Codex so its renderer applies the new
setting, then run status again. If status remains inconsistent, repair the companion. Raw process
arguments are never included in status or logs.

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
