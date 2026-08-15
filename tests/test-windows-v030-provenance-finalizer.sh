#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
finalizer="$repo_root/scripts/finalize-windows-v030-provenance.py"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
source_commit="0123456789abcdef0123456789abcdef01234567"
packaging_commit="fedcba9876543210fedcba9876543210fedcba98"

write_provenance() {
  local output="$1"
  local profile="$2"
  local validated="$3"
  python3 - "$output" "$profile" "$validated" "$source_commit" "$packaging_commit" <<'PY'
import json
import sys

output, profile, validated, source_commit, packaging_commit = sys.argv[1:]
data = {
    "schemaVersion": 1,
    "status": "release-candidate",
    "version": "0.3.0",
    "architecture": "x64",
    "runtimeIdentifier": "win-x64",
    "sourceCommit": source_commit,
    "validatedSourceCommit": source_commit,
    "packagingCommit": packaging_commit,
    "artifact": "codex-usage-sidebar-v0.3.0-windows-x64-setup.exe",
    "sha256": "a" * 64,
    "payloadManifestSha256": "b" * 64,
    "validationEvidenceSha256": "c" * 64,
    "codexRuntime": {
        "source": "https://github.com/openai/codex/releases/download/rust-v0.147.0/codex-x86_64-pc-windows-msvc.exe",
        "sha256": "935a1911ed2556e4ffcec995f4886ac2ac425863ba26fed264df62e30272ad9d",
    },
    "realDeviceValidated": validated == "true",
    "publishableInstaller": True,
    "authenticodeStatus": "NotSigned",
    "signerSubject": None,
}
if profile != "formal":
    data["validationProfile"] = profile
with open(output, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY
}

write_provenance "$fixture/formal.json" formal true
write_provenance "$fixture/quick.json" quick-prerelease false
write_provenance "$fixture/quick-validated.json" quick-prerelease true
write_provenance "$fixture/formal-unvalidated.json" formal false
write_provenance "$fixture/wrong-marker.json" formal false
python3 - "$fixture/wrong-marker.json" <<'PY'
import json
import sys
path = sys.argv[1]
data = json.load(open(path, encoding="utf-8"))
data["validationProfile"] = "formal"
json.dump(data, open(path, "w", encoding="utf-8"), indent=2, sort_keys=True)
PY

finalize() {
  local input="$1"
  local profile="$2"
  local tag="$3"
  local branch="$4"
  local validated="$5"
  local output="$6"
  local profile_args=()
  if [[ "$profile" != default ]]; then
    profile_args=(--release-profile "$profile")
  fi
  python3 "$finalizer" \
    --input "$input" \
    --output "$output" \
    "${profile_args[@]}" \
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
    --release-tag "$tag"
}

finalize "$fixture/formal.json" default v0.3.0 v0.3.0 "$source_commit" "$fixture/formal-final.json"
finalize "$fixture/quick.json" quick-prerelease v0.3.0-rc.1 v0.3.0 "$source_commit" "$fixture/quick-final.json"
python3 - "$fixture/formal-final.json" "$fixture/quick-final.json" <<'PY'
import json
import sys

formal = json.load(open(sys.argv[1], encoding="utf-8"))
quick = json.load(open(sys.argv[2], encoding="utf-8"))
assert "validationProfile" not in formal
assert formal["realDeviceValidated"] is True
assert formal["release"]["tag"] == "v0.3.0"
assert quick["validationProfile"] == "quick-prerelease"
assert quick["realDeviceValidated"] is False
assert quick["publishableInstaller"] is True
assert quick["release"]["tag"] == "v0.3.0-rc.1"
assert quick["ci"]["sourceCommit"] == quick["packagingCommit"]
assert quick["ci"]["validatedSourceCommit"] == quick["validatedSourceCommit"]
PY

assert_rejected() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    printf '%s unexpectedly succeeded\n' "$label" >&2
    exit 1
  fi
}

assert_rejected "formal profile accepted quick provenance" \
  finalize "$fixture/quick.json" formal v0.3.0 v0.3.0 "$source_commit" "$fixture/cross-formal.json"
assert_rejected "quick profile accepted formal provenance" \
  finalize "$fixture/formal.json" quick-prerelease v0.3.0-rc.1 v0.3.0 "$source_commit" "$fixture/cross-quick.json"
assert_rejected "quick profile accepted the stable tag" \
  finalize "$fixture/quick.json" quick-prerelease v0.3.0 v0.3.0 "$source_commit" "$fixture/quick-stable-tag.json"
assert_rejected "formal profile accepted the rc tag" \
  finalize "$fixture/formal.json" formal v0.3.0-rc.1 v0.3.0 "$source_commit" "$fixture/formal-rc-tag.json"
assert_rejected "quick profile accepted real-device validation" \
  finalize "$fixture/quick-validated.json" quick-prerelease v0.3.0-rc.1 v0.3.0 "$source_commit" "$fixture/quick-validated-final.json"
assert_rejected "formal profile accepted missing real-device validation" \
  finalize "$fixture/formal-unvalidated.json" formal v0.3.0 v0.3.0 "$source_commit" "$fixture/formal-unvalidated-final.json"
assert_rejected "quick profile accepted a formal marker" \
  finalize "$fixture/wrong-marker.json" quick-prerelease v0.3.0-rc.1 v0.3.0 "$source_commit" "$fixture/wrong-marker-final.json"
assert_rejected "candidate used the wrong branch" \
  finalize "$fixture/formal.json" formal v0.3.0 main "$source_commit" "$fixture/wrong-branch.json"
assert_rejected "candidate used the wrong validated source" \
  finalize "$fixture/formal.json" formal v0.3.0 v0.3.0 aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa "$fixture/wrong-source.json"

printf 'PASS: Windows candidate provenance rejects every profile, tag, flag, and source crossing\n'
