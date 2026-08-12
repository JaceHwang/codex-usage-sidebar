#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
builder="$repo_root/scripts/build-macos-v030-installer.sh"
packager="$repo_root/scripts/package-macos-v030-installer.sh"
verifier="$repo_root/scripts/verify-macos-v030-installer-package.sh"
finalizer="$repo_root/scripts/finalize-macos-v030-provenance.py"

for script in "$builder" "$packager" "$verifier" "$finalizer"; do
  [[ -f "$script" ]] || { printf 'missing macOS v0.3.0 release script: %s\n' "$script" >&2; exit 1; }
done

python3 - "$builder" "$packager" "$verifier" "$finalizer" <<'PY'
import sys
from pathlib import Path

builder, packager, verifier, finalizer = [Path(path).read_text(encoding="utf-8") for path in sys.argv[1:]]
combined = "\n".join((builder, packager, verifier, finalizer))

required = (
    'version="0.3.0"',
    'required_branch="v0.3.0"',
    'codex-usage-sidebar-v0.3.0-macos-arm64.dmg',
    '--arch arm64',
    'lipo -archs',
    'codesign --verify --deep --strict',
    'InstallerPayloadCommit',
    'validatedSourceCommit',
    'packagingCommit',
    'MACOS-V030-PROVENANCE.json',
    'MACOS-V030-SHA256SUMS.txt',
)
for marker in required:
    if marker not in combined:
        raise SystemExit(f"macOS v0.3.0 release pipeline is missing: {marker}")

if 'x86_64' in combined:
    raise SystemExit("macOS v0.3.0 release pipeline must remain arm64-only")
if 'gh release' in combined or 'softprops/action-gh-release' in combined:
    raise SystemExit("macOS candidate scripts must not publish a GitHub release")
if '.dist/codex-usage-sidebar-v0.2.3-macos-arm64.dmg' in combined:
    raise SystemExit("macOS v0.3.0 scripts reference the frozen v0.2.3 asset path")
PY

for frozen in \
  scripts/build-installer.sh \
  scripts/package-installer.sh \
  scripts/verify-installer-package.sh \
  scripts/finalize-installer-provenance.py \
  .github/workflows/publish-installer.yml; do
  git -C "$repo_root" show "HEAD:$frozen" | python3 -c \
    'import pathlib,sys; expected=sys.stdin.buffer.read().replace(b"\r\n",b"\n"); actual=pathlib.Path(sys.argv[1]).read_bytes().replace(b"\r\n",b"\n"); raise SystemExit(0 if actual == expected else 1)' \
    "$repo_root/$frozen" || {
    printf 'frozen macOS v0.2.3 release file changed: %s\n' "$frozen" >&2
    exit 1
  }
done

fixture_root="$(mktemp -d)"
trap 'rm -rf "$fixture_root"' EXIT
source_commit="0123456789abcdef0123456789abcdef01234567"
packaging_commit="fedcba9876543210fedcba9876543210fedcba98"
cat >"$fixture_root/provenance.json" <<JSON
{
  "schemaVersion": 3,
  "status": "release-candidate",
  "version": "0.3.0",
  "platform": "macos",
  "architecture": "arm64",
  "sourceCommit": "$source_commit",
  "validatedSourceCommit": "$source_commit",
  "packagingCommit": "$packaging_commit",
  "payloadCommit": "$source_commit",
  "asset": {
    "name": "codex-usage-sidebar-v0.3.0-macos-arm64.dmg",
    "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  },
  "installer": {"executableSha256": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "signature": "adhoc"},
  "companion": {"executableSha256": "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"},
  "sdk": {"name": "macosx", "version": "26.0"},
  "notarized": false
}
JSON
finalize() {
  local branch="$1"
  local output="$2"
  python3 "$finalizer" \
    --input "$fixture_root/provenance.json" \
    --output "$output" \
    --expected-repository JaceHwang/codex-usage-sidebar \
    --run-repository JaceHwang/codex-usage-sidebar \
    --run-id 123456 \
    --run-url https://github.com/JaceHwang/codex-usage-sidebar/actions/runs/123456 \
    --head-sha "$packaging_commit" \
    --validated-source-sha "$source_commit" \
    --workflow-path .github/workflows/v030-release-candidates.yml \
    --event push \
    --branch "$branch" \
    --artifact-id 987654 \
    --artifact-name codex-usage-sidebar-v0.3.0-macos-arm64-candidate \
    --artifact-digest sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd \
    --release-tag v0.3.0 \
    --sdk-version 26.0
}
finalize v0.3.0 "$fixture_root/final.json"
python3 - "$fixture_root/final.json" <<'PY'
import json
import sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["ci"]["branch"] == "v0.3.0"
assert data["artifactRecord"]["name"] == "codex-usage-sidebar-v0.3.0-macos-arm64-candidate"
assert data["release"]["tag"] == "v0.3.0"
PY
if finalize main "$fixture_root/wrong-branch.json" >/dev/null 2>&1; then
  printf 'macOS v0.3.0 provenance accepted a non-v0.3.0 branch\n' >&2
  exit 1
fi
printf 'PASS: macOS v0.3.0 arm64 candidate pipeline is isolated from frozen v0.2.3 assets\n'
