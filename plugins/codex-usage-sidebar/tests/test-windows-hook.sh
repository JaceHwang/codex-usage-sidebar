#!/usr/bin/env bash
set -euo pipefail

plugin_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
hooks="$plugin_root/hooks/hooks.json"
control="$plugin_root/scripts/sidebar-control-windows.ps1"
plugin_json="$plugin_root/.codex-plugin/plugin.json"
release_catalog="$plugin_root/../../releases/platform-release-catalog.json"

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
python3 - "$plugin_json" "$release_catalog" <<'PY'
import json
import sys
from pathlib import Path

version = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))["version"]
candidate = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))["activeCandidate"]
assert version.split("+", 1)[0] == candidate["version"], version
assert candidate["tag"] == f"{candidate['platform']}-v{candidate['version']}", candidate
assert version == candidate["version"] or "+codex." in version, version
PY
grep -q 'version=0.3.5' "$control"
if grep -Eq 'version=0\.3\.[0-4]' "$control"; then
  printf 'current Windows control script must not emit an older product version\n' >&2
  exit 1
fi
grep -q 'runtime=stopped reason=not-running version=0.3.5' "$control"
if grep -q 'reason=device-validation-required' "$control"; then
  printf 'Windows control script must not report the retired device-validation gate\n' >&2
  exit 1
fi
if grep -Eiq 'Invoke-Expression|cmd(\.exe)?[[:space:]]+/c' "$control"; then
  printf 'Windows control script contains a shell-evaluation escape hatch\n' >&2
  exit 1
fi

printf 'PASS: Windows hook uses the fixed PowerShell control boundary\n'
