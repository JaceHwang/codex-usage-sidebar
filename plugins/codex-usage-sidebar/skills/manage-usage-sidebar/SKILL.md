---
name: manage-usage-sidebar
description: Install, check, repair, or uninstall the native Codex Usage Sidebar companion. Use when the user asks about the Codex usage header indicator, says it disappeared after a Codex update, requests repair, status, installation, or removal, or invokes @codex-usage-sidebar.
---

# Manage Codex Usage Sidebar

Use the plugin control script. Keep the native companion outside the signed Codex
application bundle so official upgrades cannot overwrite it.

## Commands

- Install or refresh:
  `bash "$PLUGIN_ROOT/scripts/sidebar-control.sh" ensure --plugin-root "$PLUGIN_ROOT" --plugin-data "$PLUGIN_DATA"`
- Check:
  `bash "$PLUGIN_ROOT/scripts/sidebar-control.sh" status --plugin-root "$PLUGIN_ROOT" --plugin-data "$PLUGIN_DATA"`
- Repair:
  `bash "$PLUGIN_ROOT/scripts/sidebar-control.sh" repair --plugin-root "$PLUGIN_ROOT" --plugin-data "$PLUGIN_DATA"`
- Uninstall only when explicitly requested:
  `bash "$PLUGIN_ROOT/scripts/sidebar-control.sh" uninstall --plugin-root "$PLUGIN_ROOT" --plugin-data "$PLUGIN_DATA"`

On Windows, use the PowerShell control script instead:

```powershell
$control = Join-Path $env:PLUGIN_ROOT 'scripts\sidebar-control-windows.ps1'
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $control ensure -PluginRoot $env:PLUGIN_ROOT -PluginData $env:PLUGIN_DATA
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $control status -PluginRoot $env:PLUGIN_ROOT -PluginData $env:PLUGIN_DATA
```

The Windows status `runtime=stopped reason=not-running` means the installed companion is not
currently running; it is not a device-validation gate. Run `ensure` once, or restart Codex so the
SessionStart hook starts it automatically. A missing titlebar, unsupported UIA structure, or stale
Codex process is reported by the running companion's diagnostic state instead of blocking install.

After install or repair, tell the user that macOS may require one-time Accessibility
permission for Codex Usage Sidebar. Never claim that permission was granted unless
the operating system reports it.

For language reports, use the sanitized `language=` and `language_source=` fields from
status. `process` reflects Codex's effective displayed locale, including Auto; do not
request or expose raw process arguments.
