#!/usr/bin/env bash
set -euo pipefail

plugin_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
hooks="$plugin_root/hooks/hooks.json"
control="$plugin_root/scripts/sidebar-control-windows.ps1"

python3 - "$hooks" <<'PY'
import json
import sys
from pathlib import Path

document = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
hook = document["hooks"]["SessionStart"][0]["hooks"][0]
command = hook.get("commandWindows", "")
assert "powershell.exe" in command
assert "sidebar-control-windows.ps1" in command
assert "${PLUGIN_ROOT}" in command
assert "${PLUGIN_DATA}" in command
PY

[[ -f "$control" ]]
grep -q 'version=0.3.3' "$control"
if grep -q 'version=0.3.2' "$control"; then
  printf 'v0.3.3 control script must not emit v0.3.2 status labels\n' >&2
  exit 1
fi
if grep -Eiq 'Invoke-Expression|cmd(\.exe)?[[:space:]]+/c' "$control"; then
  printf 'Windows control script contains a shell-evaluation escape hatch\n' >&2
  exit 1
fi

printf 'PASS: Windows hook uses the fixed PowerShell control boundary\n'
