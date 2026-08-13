#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_root="$(mktemp -d)"
trap 'rm -rf "$fixture_root"' EXIT
formal_evidence="$fixture_root/formal-evidence.json"
quick_evidence="$fixture_root/quick-evidence.json"
source_commit="0123456789abcdef0123456789abcdef01234567"
codex_source="https://github.com/openai/codex/releases/download/rust-v0.147.0/codex-x86_64-pc-windows-msvc.exe"

new_payload() {
  local payload="$1"
  mkdir -p "$payload"
  printf 'host' >"$payload/CodexUsageSidebar.Windows.exe"
  printf 'control' >"$payload/CodexUsageSidebar.Control.exe"
  printf 'runtime' >"$payload/codex.exe"
  printf '{"schemaVersion":1,"builds":[]}' >"$payload/selectors.json"
}

assert_rejected() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    printf '%s unexpectedly succeeded\n' "$label" >&2
    exit 1
  fi
}

python3 "$repo_root/scripts/new-windows-v030-validation-template.py" \
  --source-commit "$source_commit" --windows-build 26100 \
  --codex-file-build 151.0.7922.76 --output "$formal_evidence"
python3 - "$formal_evidence" <<'PY'
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
python3 "$repo_root/scripts/record-windows-v030-quick-prerelease.py" init "$quick_evidence" \
  --source-commit "$source_commit" --windows-build 26100 --codex-file-build 151.0.7922.76
python3 "$repo_root/scripts/record-windows-v030-quick-prerelease.py" complete "$quick_evidence"

formal_payload="$fixture_root/formal-payload"
quick_payload="$fixture_root/quick-payload"
new_payload "$formal_payload"
new_payload "$quick_payload"
runtime_sha="$(shasum -a 256 "$formal_payload/codex.exe" | awk '{print $1}')"

python3 "$repo_root/scripts/build-windows-v030-release-manifest.py" \
  --payload-dir "$formal_payload" --version 0.3.0 --architecture x64 \
  --source-commit "$source_commit" --codex-source "$codex_source" \
  --codex-sha256 "$runtime_sha" --validation-evidence "$formal_evidence"
python3 "$repo_root/scripts/verify-windows-v030-release-payload.py" "$formal_payload"

python3 "$repo_root/scripts/build-windows-v030-release-manifest.py" \
  --release-profile quick-prerelease \
  --payload-dir "$quick_payload" --version 0.3.0 --architecture x64 \
  --source-commit "$source_commit" --codex-source "$codex_source" \
  --codex-sha256 "$runtime_sha" --validation-evidence "$quick_evidence"
python3 "$repo_root/scripts/verify-windows-v030-release-payload.py" \
  --release-profile quick-prerelease "$quick_payload"

python3 - "$formal_payload/windows-payload.json" "$quick_payload/windows-payload.json" <<'PY'
import json
import sys

formal = json.load(open(sys.argv[1], encoding="utf-8"))
quick = json.load(open(sys.argv[2], encoding="utf-8"))
assert "validationProfile" not in formal
assert formal["realDeviceValidated"] is True
assert formal["publishableInstaller"] is True
assert "realDeviceValidation" in formal
assert "quickPrereleaseValidation" not in formal
assert formal["realDeviceValidation"]["sha256"] == formal["files"]["windows-validation.json"]
assert quick["validationProfile"] == "quick-prerelease"
assert quick["realDeviceValidated"] is False
assert quick["publishableInstaller"] is True
assert "realDeviceValidation" not in quick
assert "quickPrereleaseValidation" in quick
assert quick["quickPrereleaseValidation"]["sha256"] == quick["files"]["windows-validation.json"]
PY

assert_rejected "formal verifier on quick payload" \
  python3 "$repo_root/scripts/verify-windows-v030-release-payload.py" "$quick_payload"
assert_rejected "quick verifier on formal payload" \
  python3 "$repo_root/scripts/verify-windows-v030-release-payload.py" \
    --release-profile quick-prerelease "$formal_payload"

formal_cross_payload="$fixture_root/formal-cross-payload"
quick_cross_payload="$fixture_root/quick-cross-payload"
new_payload "$formal_cross_payload"
new_payload "$quick_cross_payload"
assert_rejected "quick profile with formal evidence" \
  python3 "$repo_root/scripts/build-windows-v030-release-manifest.py" \
    --release-profile quick-prerelease \
    --payload-dir "$quick_cross_payload" --version 0.3.0 --architecture x64 \
    --source-commit "$source_commit" --codex-source "$codex_source" \
    --codex-sha256 "$runtime_sha" --validation-evidence "$formal_evidence"
assert_rejected "formal profile with quick evidence" \
  python3 "$repo_root/scripts/build-windows-v030-release-manifest.py" \
    --payload-dir "$formal_cross_payload" --version 0.3.0 --architecture x64 \
    --source-commit "$source_commit" --codex-source "$codex_source" \
    --codex-sha256 "$runtime_sha" --validation-evidence "$quick_evidence"

cp "$quick_payload/windows-payload.json" "$fixture_root/valid-quick-manifest.json"
python3 - "$quick_payload/windows-payload.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
document = json.loads(path.read_text(encoding="utf-8"))
document["realDeviceValidated"] = True
path.write_text(json.dumps(document), encoding="utf-8")
PY
assert_rejected "quick payload claiming real-device validation" \
  python3 "$repo_root/scripts/verify-windows-v030-release-payload.py" \
    --release-profile quick-prerelease "$quick_payload"
cp "$fixture_root/valid-quick-manifest.json" "$quick_payload/windows-payload.json"
python3 - "$quick_payload/windows-payload.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
document = json.loads(path.read_text(encoding="utf-8"))
document["validationProfile"] = "formal"
path.write_text(json.dumps(document), encoding="utf-8")
PY
assert_rejected "quick payload with formal marker" \
  python3 "$repo_root/scripts/verify-windows-v030-release-payload.py" \
    --release-profile quick-prerelease "$quick_payload"

cp "$formal_payload/windows-payload.json" "$fixture_root/valid-formal-manifest.json"
python3 - "$formal_payload/windows-payload.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
document = json.loads(path.read_text(encoding="utf-8"))
document["realDeviceValidated"] = False
path.write_text(json.dumps(document), encoding="utf-8")
PY
assert_rejected "formal payload dropping real-device validation" \
  python3 "$repo_root/scripts/verify-windows-v030-release-payload.py" "$formal_payload"
cp "$fixture_root/valid-formal-manifest.json" "$formal_payload/windows-payload.json"

python3 - "$quick_payload/windows-validation.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
document = json.loads(path.read_text(encoding="utf-8"))
document["smoke"]["manager"] = "fail"
path.write_text(json.dumps(document), encoding="utf-8")
PY
cp "$fixture_root/valid-quick-manifest.json" "$quick_payload/windows-payload.json"
assert_rejected "tampered quick smoke evidence" \
  python3 "$repo_root/scripts/verify-windows-v030-release-payload.py" \
    --release-profile quick-prerelease "$quick_payload"

assert_rejected "non-v0.3.0 version" \
  python3 "$repo_root/scripts/build-windows-v030-release-manifest.py" \
    --payload-dir "$formal_cross_payload" --version 0.3.0-beta.1 --architecture x64 \
    --source-commit "$source_commit" --codex-source "$codex_source" \
    --codex-sha256 "$runtime_sha" --validation-evidence "$formal_evidence"

printf 'PASS: Windows v0.3.0 payload profiles bind only their exact evidence and validation state\n'
