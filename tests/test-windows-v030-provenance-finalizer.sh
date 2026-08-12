#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
finalizer="$repo_root/scripts/finalize-windows-v030-provenance.py"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
source_commit="0123456789abcdef0123456789abcdef01234567"
packaging_commit="fedcba9876543210fedcba9876543210fedcba98"

cat >"$fixture/provenance.json" <<JSON
{
  "schemaVersion": 1,
  "status": "release-candidate",
  "version": "0.3.0",
  "architecture": "x64",
  "runtimeIdentifier": "win-x64",
  "sourceCommit": "$source_commit",
  "validatedSourceCommit": "$source_commit",
  "packagingCommit": "$packaging_commit",
  "artifact": "codex-usage-sidebar-v0.3.0-windows-x64-setup.exe",
  "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "payloadManifestSha256": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  "validationEvidenceSha256": "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
  "codexRuntime": {
    "source": "https://github.com/openai/codex/releases/download/rust-v0.147.0/codex-x86_64-pc-windows-msvc.exe",
    "sha256": "935a1911ed2556e4ffcec995f4886ac2ac425863ba26fed264df62e30272ad9d"
  },
  "realDeviceValidated": true,
  "publishableInstaller": true,
  "authenticodeStatus": "NotSigned",
  "signerSubject": null
}
JSON

finalize() {
  local branch="$1"
  local validated="$2"
  local output="$3"
  python3 "$finalizer" \
    --input "$fixture/provenance.json" \
    --output "$output" \
    --expected-repository JaceHwang/codex-usage-sidebar \
    --run-repository JaceHwang/codex-usage-sidebar \
    --run-id 123456 \
    --run-url https://github.com/JaceHwang/codex-usage-sidebar/actions/runs/123456 \
    --head-sha "$packaging_commit" \
    --validated-source-sha "$validated" \
    --workflow-path .github/workflows/v030-release-candidates.yml \
    --event push \
    --branch "$branch" \
    --artifact-id 987654 \
    --artifact-name codex-usage-sidebar-v0.3.0-windows-x64-candidate \
    --artifact-digest sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd \
    --release-tag v0.3.0
}

finalize v0.3.0 "$source_commit" "$fixture/final.json"
python3 - "$fixture/final.json" <<'PY'
import json
import sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
assert data["ci"]["sourceCommit"] == data["packagingCommit"]
assert data["ci"]["validatedSourceCommit"] == data["validatedSourceCommit"]
assert data["artifactRecord"]["name"] == "codex-usage-sidebar-v0.3.0-windows-x64-candidate"
assert data["release"]["tag"] == "v0.3.0"
PY

if finalize main "$source_commit" "$fixture/wrong-branch.json" >/dev/null 2>&1; then
  printf 'Windows provenance accepted a non-v0.3.0 branch\n' >&2
  exit 1
fi
if finalize v0.3.0 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa "$fixture/wrong-source.json" >/dev/null 2>&1; then
  printf 'Windows provenance accepted the wrong validated source\n' >&2
  exit 1
fi

printf 'PASS: Windows v0.3.0 candidate provenance binds validated source, packaging run, and artifact\n'
