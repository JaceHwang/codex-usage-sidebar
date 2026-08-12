#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_root="$(mktemp -d)"
trap 'rm -rf "$fixture_root"' EXIT
payload="$fixture_root/payload"
evidence="$fixture_root/evidence.json"
mkdir -p "$payload"

printf 'host' >"$payload/CodexUsageSidebar.Windows.exe"
printf 'control' >"$payload/CodexUsageSidebar.Control.exe"
printf 'runtime' >"$payload/codex.exe"
printf '{"schemaVersion":1,"builds":[]}' >"$payload/selectors.json"
runtime_sha="$(shasum -a 256 "$payload/codex.exe" | awk '{print $1}')"
source_commit="0123456789abcdef0123456789abcdef01234567"
codex_source="https://github.com/openai/codex/releases/download/rust-v0.147.0/codex-x86_64-pc-windows-msvc.exe"

python3 "$repo_root/scripts/new-windows-v030-validation-template.py" \
  --source-commit "$source_commit" --windows-build 26100 \
  --codex-file-build 151.0.7922.76 --output "$evidence"
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

python3 "$repo_root/scripts/build-windows-v030-release-manifest.py" \
  --payload-dir "$payload" --version 0.3.0 --architecture x64 \
  --source-commit "$source_commit" --codex-source "$codex_source" \
  --codex-sha256 "$runtime_sha" --validation-evidence "$evidence"
python3 "$repo_root/scripts/verify-windows-v030-release-payload.py" "$payload"

python3 - "$payload/windows-payload.json" <<'PY'
import json
import sys
from pathlib import Path

manifest = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert manifest["version"] == "0.3.0"
assert manifest["architecture"] == "x64"
assert manifest["status"] == "release"
assert manifest["realDeviceValidated"] is True
assert manifest["publishableInstaller"] is True
assert manifest["realDeviceValidation"]["sha256"] == manifest["files"]["windows-validation.json"]
PY

cp "$payload/windows-payload.json" "$fixture_root/valid-manifest.json"
python3 - "$payload/windows-validation.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
document = json.loads(path.read_text(encoding="utf-8"))
document["cases"]["lifecycle"][0]["result"] = "pending"
path.write_text(json.dumps(document), encoding="utf-8")
PY
if python3 "$repo_root/scripts/verify-windows-v030-release-payload.py" "$payload" >/dev/null 2>&1; then
  printf 'tampered Windows validation evidence unexpectedly passed release payload verification\n' >&2
  exit 1
fi
cp "$evidence" "$payload/windows-validation.json"
cp "$fixture_root/valid-manifest.json" "$payload/windows-payload.json"

if python3 "$repo_root/scripts/build-windows-v030-release-manifest.py" \
  --payload-dir "$payload" --version 0.3.0-beta.1 --architecture x64 \
  --source-commit "$source_commit" --codex-source "$codex_source" \
  --codex-sha256 "$runtime_sha" --validation-evidence "$evidence" >/dev/null 2>&1; then
  printf 'beta version unexpectedly produced a Windows v0.3.0 release manifest\n' >&2
  exit 1
fi

printf 'PASS: Windows v0.3.0 release payload is bound to complete real-device evidence\n'
