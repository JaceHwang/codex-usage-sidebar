#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
binary="$repo_root/plugins/codex-usage-sidebar/assets/Codex Usage Sidebar.app/Contents/MacOS/CodexUsageSidebar"
provenance="$repo_root/plugins/codex-usage-sidebar/assets/PROVENANCE.json"

[[ -x "$binary" && -f "$provenance" ]] || {
  printf 'marketplace companion or provenance is missing\n' >&2
  exit 1
}

actual="$(/usr/bin/shasum -a 256 "$binary" | /usr/bin/awk '{print $1}')"
expected="$(/usr/bin/python3 - "$provenance" <<'PY'
import json
import sys

print(json.load(open(sys.argv[1], encoding="utf-8"))["companion"]["executableSha256"])
PY
)"

[[ "$actual" == "$expected" ]] || {
  printf 'marketplace companion hash differs from provenance: %s != %s\n' "$actual" "$expected" >&2
  exit 1
}

printf 'PASS: marketplace companion hash matches provenance\n'
