#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_root="$(mktemp -d)"
trap 'rm -rf "$fixture_root"' EXIT

mode="${1:---full-chain}"
case "$mode" in
  --evidence-only|--full-chain) ;;
  *)
    printf 'usage: %s [--evidence-only|--full-chain]\n' "$0" >&2
    exit 2
    ;;
esac

if command -v python >/dev/null 2>&1; then
  python_cmd="python"
elif command -v python3 >/dev/null 2>&1; then
  python_cmd="python3"
else
  printf 'Python 3 is required to run the v0.3.3 release-chain contract\n' >&2
  exit 1
fi
if command -v pwsh >/dev/null 2>&1; then
  pwsh_cmd="pwsh"
elif command -v pwsh.exe >/dev/null 2>&1; then
  pwsh_cmd="pwsh.exe"
else
  printf 'PowerShell 7 is required to run the v0.3.3 release-chain contract\n' >&2
  exit 1
fi

path_for_pwsh() {
  if [[ "$pwsh_cmd" == *.exe ]]; then
    if command -v cygpath >/dev/null 2>&1; then
      cygpath -w "$1"
    elif command -v wslpath >/dev/null 2>&1; then
      wslpath -w "$1"
    else
      printf 'A Windows-path conversion tool is required for pwsh.exe\n' >&2
      exit 1
    fi
  else
    printf '%s\n' "$1"
  fi
}

binding_test="$(path_for_pwsh "$repo_root/tests/test-windows-v033-evidence-binding.ps1")"
"$pwsh_cmd" -NoProfile -File "$binding_test"

selector_catalog_test="$(path_for_pwsh "$repo_root/tests/test-windows-v033-selector-catalog.ps1")"
"$pwsh_cmd" -NoProfile -File "$selector_catalog_test"

ps_repo_root="$(path_for_pwsh "$repo_root")"
ps_script="$ps_repo_root/scripts/build-windows-v033-setup.ps1"

plan="$("$pwsh_cmd" -NoProfile -File "$ps_script" -PlanOnly)"
PLAN="$plan" "$python_cmd" - <<'PY'
import json
import os

plan = json.loads(os.environ["PLAN"])
assert plan["version"] == "0.3.3"
assert plan["architecture"] == "x64"
assert plan["selectorsSchemaVersion"] == 2
assert plan["publishableInstaller"] is False
PY

"$python_cmd" - "$repo_root/scripts/v033_release_profiles.py" <<'PY'
import importlib.util
import sys

path = sys.argv[1]
spec = importlib.util.spec_from_file_location("v033_release_profiles", path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
assert dict(module.FORMAL) == {
    "releaseProfile": "formal",
    "tag": "v0.3.3",
    "evidencePath": "docs/validation/windows-v0.3.3.json",
    "realDeviceValidated": True,
}
try:
    module.FORMAL["tag"] = "tampered"
except TypeError:
    pass
else:
    raise AssertionError("FORMAL metadata must be immutable")
PY

valid_spki='MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEGhz+XZxUarxEbLW+RiAf4QtCMvX5rIUA+6yTie9NyM+8erFgK6sbNKalTzTwCu4MLpVI6fqW2CAQ5Y8t/oi7ig=='
assert_no_artifacts() {
  local output_dir="$1"
  if [[ -e "$output_dir" ]] && find "$output_dir" -type f -print -quit | grep -q .; then
    printf 'v0.3.3 build emitted artifacts at the missing/invalid evidence boundary\n' >&2
    exit 1
  fi
}

validation_commit="0123456789abcdef0123456789abcdef01234567"
incomplete_validation="$fixture_root/v033-incomplete-validation.json"
complete_validation="$fixture_root/v033-complete-validation.json"
"$python_cmd" - "$incomplete_validation" "$complete_validation" "$validation_commit" <<'PY'
import json
import pathlib
import sys
from itertools import product

incomplete_path = pathlib.Path(sys.argv[1])
complete_path = pathlib.Path(sys.argv[2])
source_commit = sys.argv[3]

document = {
    "schemaVersion": 1,
    "version": "0.3.3",
    "sourceCommit": source_commit,
    "architecture": "x64",
    "windowsBuild": 22631,
    "codexFileBuild": "151.0.7922.76",
    "completedAt": "2026-08-23T00:00:00Z",
    "cases": {
        "visual": [
            {
                "layout": layout,
                "theme": theme,
                "language": language,
                "scale": scale,
                "result": "pass",
            }
            for layout, scale, theme, language in product(
                ("wide", "narrow", "right-pane"),
                (100, 125, 150, 200),
                ("light", "dark", "system"),
                ("en", "zh-CN"),
            )
        ],
        "geometry": [
            {"name": name, "result": "pass"}
            for name in ("restored", "maximized", "fullscreen")
        ],
        "interaction": [
            {"name": name, "result": "pass"}
            for name in (
                "safe-dock-drag-snap",
                "safe-dock-lock-reset",
                "three-success-recovery",
            )
        ],
        "lifecycle": [
            {"name": name, "result": "pass"}
            for name in (
                "codex-restart-update",
                "sleep-resume",
                "app-server-recovery",
                "install-repair",
                "upgrade-retains-preferences",
                "uninstall",
                "package-provenance",
            )
        ],
    },
}
complete_path.write_text(json.dumps(document), encoding="utf-8")
document["cases"]["visual"].pop()
incomplete_path.write_text(json.dumps(document), encoding="utf-8")
PY

assert_validation_rejected() {
  local label="$1"
  local evidence="$2"
  if "$python_cmd" "$repo_root/scripts/verify-windows-v033-validation.py" \
    "$evidence" --source-commit "$validation_commit"; then
    printf 'v0.3.3 validator unexpectedly accepted %s evidence\n' "$label" >&2
    exit 1
  fi
}

assert_validation_rejected incomplete "$incomplete_validation"
"$python_cmd" "$repo_root/scripts/verify-windows-v033-validation.py" \
  "$complete_validation" --source-commit "$validation_commit"

"$python_cmd" - "$complete_validation" "$fixture_root/v033-duplicate-validation.json" \
  "$fixture_root/v033-invalid-build-validation.json" "$fixture_root/v033-invalid-version-validation.json" \
  "$fixture_root/v033-non-pass-validation.json" "$fixture_root/v033-offset-completed-at-validation.json" \
  "$fixture_root/v033-fractional-completed-at-validation.json" "$fixture_root/v033-invalid-date-completed-at-validation.json" <<'PY'
import json
import pathlib
import sys

complete = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
for output, mutate in (
    (sys.argv[2], lambda value: value["cases"]["visual"].append(value["cases"]["visual"][0].copy())),
    (sys.argv[3], lambda value: value.__setitem__("windowsBuild", 19045)),
    (sys.argv[4], lambda value: value.__setitem__("version", "0.3.2")),
    (sys.argv[5], lambda value: value["cases"]["lifecycle"][0].__setitem__("result", "fail")),
    (sys.argv[6], lambda value: value.__setitem__("completedAt", "2026-08-23T00:00:00+00:00")),
    (sys.argv[7], lambda value: value.__setitem__("completedAt", "2026-08-23T00:00:00.001Z")),
    (sys.argv[8], lambda value: value.__setitem__("completedAt", "2026-02-30T00:00:00Z")),
):
    value = json.loads(json.dumps(complete))
    mutate(value)
    pathlib.Path(output).write_text(json.dumps(value), encoding="utf-8")
PY

assert_validation_rejected duplicate "$fixture_root/v033-duplicate-validation.json"
assert_validation_rejected invalid-build "$fixture_root/v033-invalid-build-validation.json"
assert_validation_rejected invalid-version "$fixture_root/v033-invalid-version-validation.json"
assert_validation_rejected non-pass "$fixture_root/v033-non-pass-validation.json"
assert_validation_rejected offset-completed-at "$fixture_root/v033-offset-completed-at-validation.json"
assert_validation_rejected fractional-completed-at "$fixture_root/v033-fractional-completed-at-validation.json"
assert_validation_rejected invalid-date-completed-at "$fixture_root/v033-invalid-date-completed-at-validation.json"

assert_setup_input_rejected() {
  local label="$1"
  local key="$2"
  local uri="$3"
  local output_file="$fixture_root/v033-$label-setup.txt"
  if "$pwsh_cmd" -NoProfile -File "$ps_script" -ValidationEvidence "$(path_for_pwsh "$complete_validation")" \
      -OutputDirectory "$(path_for_pwsh "$fixture_root/$label-out")" \
      -CompatibilityPublicKey "$key" -CompatibilityUpdateUri "$uri" >"$output_file" 2>&1; then
    printf 'v0.3.3 setup unexpectedly accepted %s compatibility input\n' "$label" >&2
    exit 1
  fi
  grep -Fq 'requires a valid P-256 SPKI public key and HTTPS compatibility update URI.' "$output_file" || {
    printf 'v0.3.3 setup did not reject %s compatibility input at the input gate\n' "$label" >&2
    cat "$output_file" >&2
    exit 1
  }
}
assert_setup_input_rejected invalid-key 'not-a-p256-spki' https://example.invalid/pack.zip
assert_setup_input_rejected invalid-uri "$valid_spki" http://example.invalid/pack.zip

payload="$fixture_root/v033-payload"
mkdir -p "$payload"
for file in CodexUsageSidebar.Windows.exe CodexUsageSidebar.Control.exe codex.exe selectors.json; do
  printf '%s\n' "$file" >"$payload/$file"
done
"$python_cmd" - "$payload/selectors.json" <<'PY'
import json
import pathlib
import sys
pathlib.Path(sys.argv[1]).write_text(json.dumps({
    "schemaVersion": 2,
    "profiles": [{
        "buildIdentities": ["151.0.7922.76"],
        "markerAliases": {},
        "maxWrapperDepth": 2,
        "depthTolerance": 2,
    }],
}), encoding="utf-8")
PY
VALID_SPKI="$valid_spki" "$python_cmd" - "$payload/compatibility-update.json" <<'PY'
import json
import os
import pathlib
import sys

pathlib.Path(sys.argv[1]).write_text(json.dumps({
    "schemaVersion": 1,
    "publicKey": os.environ["VALID_SPKI"],
    "updateUri": "https://example.invalid/pack.zip",
}), encoding="utf-8")
PY
runtime_sha="$($python_cmd - "$payload/codex.exe" <<'PY'
import hashlib
import pathlib
import sys
print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())
PY
)"
"$python_cmd" "$repo_root/scripts/build-windows-v033-release-manifest.py" \
  --payload-dir "$payload" --version 0.3.3 --architecture x64 --source-commit "$validation_commit" \
  --codex-source https://github.com/openai/codex/releases/download/test/codex.exe \
  --codex-sha256 "$runtime_sha" --validation-evidence "$complete_validation"
"$python_cmd" "$repo_root/scripts/verify-windows-v033-release-payload.py" "$payload"
"$python_cmd" - "$payload/compatibility-update.json" <<'PY'
import json
import pathlib
import sys
path = pathlib.Path(sys.argv[1])
document = json.loads(path.read_text(encoding="utf-8"))
document["publicKey"] = "not-a-p256-spki"
path.write_text(json.dumps(document), encoding="utf-8")
PY
if "$python_cmd" "$repo_root/scripts/build-windows-v033-release-manifest.py" \
  --payload-dir "$payload" --version 0.3.3 --architecture x64 --source-commit "$validation_commit" \
  --codex-source https://github.com/openai/codex/releases/download/test/codex.exe \
  --codex-sha256 "$runtime_sha" --validation-evidence "$complete_validation"; then
  printf 'v0.3.3 manifest builder accepted a non-P-256 compatibility key\n' >&2
  exit 1
fi
"$python_cmd" - "$payload/windows-payload.json" <<'PY'
import json
import pathlib
import sys
path = pathlib.Path(sys.argv[1])
document = json.loads(path.read_text(encoding="utf-8"))
document["version"] = "0.3.2"
path.write_text(json.dumps(document), encoding="utf-8")
PY
if "$python_cmd" "$repo_root/scripts/verify-windows-v033-release-payload.py" "$payload"; then
  printf 'v0.3.3 payload verifier accepted a non-v0.3.3 payload\n' >&2
  exit 1
fi

"$python_cmd" - "$repo_root/docs/validation/windows-v0.3.3.schema.json" <<'PY'
import json
import pathlib
import sys

schema = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
assert schema["properties"]["completedAt"] == {
    "type": "string",
    "pattern": r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$",
}
PY

"$python_cmd" - "$repo_root" <<'PY'
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
template = (root / "docs/validation/windows-v0.3.3-real-device-template.md").read_text(encoding="utf-8")
install = (root / "docs/INSTALL.md").read_text(encoding="utf-8")
troubleshooting = (root / "docs/TROUBLESHOOTING.md").read_text(encoding="utf-8")

def require(document: str, value: str, description: str) -> None:
    if value not in document:
        raise AssertionError(f"missing v0.3.3 documentation contract: {description}")

formal_command = """```powershell
# Public inputs only — never paste a private key into this command.
pwsh scripts/build-windows-v033-setup.ps1 `
  -ValidationEvidence docs/validation/windows-v0.3.3.json `
  -OutputDirectory <outside-repository-output> `
  -CompatibilityPublicKey <base64-p256-spki> `
  -CompatibilityUpdateUri <https-compatibility-pack-uri>
```"""
require(template, formal_command, "complete runnable formal build command")
private_key_header = "BEGIN " + "PRIVATE KEY"
if "-CompatibilityPrivateKey" in template or private_key_header in template or "PRIVATE_KEY=" in template:
    raise AssertionError("v0.3.3 formal handoff must not contain a private-key command input")
require(template, "Private keys must never be stored in this repository or typed on the command line.", "private-key boundary")
require(template, "non-`v0.3.3` branch", "formal branch requirement")
require(template, "non-clean worktree", "formal clean-worktree requirement")
require(template, "complete Windows 11 AMD64/x64 matrix", "formal real-device matrix requirement")
require(template, "tested source commit", "formal source-commit binding")
require(template, "Formal v0.3.3 setup publishable: **Yes**", "published-installer statement")
require(install, "The formal v0.3.3 Windows x64 installer is published", "installation availability statement")
require(install, "do not edit `selectors.json` by hand", "ordinary-user selector guidance")
require(install, "automatic safe dock", "ordinary-user safe-dock recovery")
require(troubleshooting, "default-redacted diagnostic", "redacted diagnostic recovery")
require(troubleshooting, "not a reason to edit selector files", "ordinary-user selector recovery")
require(troubleshooting, "automatic safe dock", "automatic safe-dock recovery")
PY

if [[ "$mode" == "--full-chain" ]]; then
  output_dir="$fixture_root/full-chain-out"
  output_file="$fixture_root/full-chain-output.txt"
  ps_complete_validation="$(path_for_pwsh "$complete_validation")"
  ps_output_dir="$(path_for_pwsh "$output_dir")"
  if "$pwsh_cmd" -NoProfile -File "$ps_script" \
    -ValidationEvidence "$ps_complete_validation" -OutputDirectory "$ps_output_dir" \
    -CompatibilityPublicKey "$valid_spki" -CompatibilityUpdateUri https://example.invalid/pack.zip \
    >"$output_file" 2>&1; then
    printf 'v0.3.3 full-chain harness unexpectedly completed without a release branch\n' >&2
    exit 1
  fi
  assert_no_artifacts "$output_dir"
  if grep -Fq 'remains gated' "$output_file"; then
    printf 'v0.3.3 full-chain harness reached an unconditional placeholder gate\n' >&2
    cat "$output_file" >&2
    exit 1
  fi
  grep -Fq "Windows v0.3.3 setup must be built from the exact 'v0.3.3' branch." "$output_file" || {
    printf 'v0.3.3 full-chain harness did not reach the branch/source validation boundary\n' >&2
    cat "$output_file" >&2
    exit 1
  }
  printf 'PASS: Windows v0.3.3 full-chain reaches the branch/source validation boundary\n'
  exit 0
fi

printf 'PASS: Windows v0.3.3 evidence-only validation contract is present\n'
