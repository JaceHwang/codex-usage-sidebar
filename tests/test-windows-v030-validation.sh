#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_root="$(mktemp -d)"
trap 'rm -rf "$fixture_root"' EXIT
evidence="$fixture_root/windows-v030-validation.json"
commit="0123456789abcdef0123456789abcdef01234567"

python3 "$repo_root/scripts/new-windows-v030-validation-template.py" \
  --source-commit "$commit" \
  --windows-build 26100 \
  --codex-file-build 151.0.7922.76 \
  --output "$evidence"

python3 "$repo_root/scripts/record-windows-v030-validation.py" "$evidence" \
  visual --layout restored-collapsed --theme light --language zh-CN --scale 100
if python3 "$repo_root/scripts/record-windows-v030-validation.py" "$evidence" \
  visual --layout restored-collapsed --theme light --language zh-CN --scale 100 \
  >/dev/null 2>&1; then
  printf 'duplicate Windows visual validation case unexpectedly passed\n' >&2
  exit 1
fi

if python3 "$repo_root/scripts/verify-windows-v030-validation.py" \
  "$evidence" --source-commit "$commit" >/dev/null 2>&1; then
  printf 'pending Windows validation evidence unexpectedly passed\n' >&2
  exit 1
fi

python3 - "$evidence" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
document = json.loads(path.read_text(encoding="utf-8"))
for group in document["cases"].values():
    for case in group:
        case["result"] = "pass"
document["completedAt"] = "2026-08-13T00:00:00Z"
path.write_text(json.dumps(document, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY

python3 "$repo_root/scripts/verify-windows-v030-validation.py" \
  "$evidence" --source-commit "$commit"

if python3 "$repo_root/scripts/verify-windows-v030-validation.py" \
  "$evidence" --source-commit fedcba9876543210fedcba9876543210fedcba98 >/dev/null 2>&1; then
  printf 'wrong source commit unexpectedly passed Windows validation\n' >&2
  exit 1
fi

python3 - "$evidence" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
document = json.loads(path.read_text(encoding="utf-8"))
document["cases"]["visual"].pop()
path.write_text(json.dumps(document), encoding="utf-8")
PY
if python3 "$repo_root/scripts/verify-windows-v030-validation.py" \
  "$evidence" --source-commit "$commit" >/dev/null 2>&1; then
  printf 'incomplete Windows visual matrix unexpectedly passed\n' >&2
  exit 1
fi

printf 'PASS: Windows v0.3.0 validation evidence requires the complete x64 real-device matrix\n'
