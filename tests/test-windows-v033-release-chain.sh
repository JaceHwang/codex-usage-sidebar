#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_root="$(mktemp -d)"
trap 'rm -rf "$fixture_root"' EXIT

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
evidence_path="$repo_root/docs/validation/windows-v0.3.3.json"

assert_no_artifacts() {
  local output_dir="$1"
  if [[ -e "$output_dir" ]] && find "$output_dir" -type f -print -quit | grep -q .; then
    printf 'v0.3.3 build emitted artifacts at the missing/invalid evidence boundary\n' >&2
    exit 1
  fi
}

run_evidence_boundary_case() {
  local label="$1"
  local evidence_input="$2"
  local output_dir="$fixture_root/$label-out"
  local output_file="$fixture_root/$label-output.txt"
  local ps_evidence_input="$(path_for_pwsh "$evidence_input")"
  local ps_output_dir="$(path_for_pwsh "$output_dir")"

  if "$pwsh_cmd" -NoProfile -File "$ps_script" \
    -ValidationEvidence "$ps_evidence_input" -OutputDirectory "$ps_output_dir" \
    -CompatibilityPublicKey "$valid_spki" -CompatibilityUpdateUri https://example.invalid/pack.zip \
    >"$output_file" 2>&1; then
    printf 'v0.3.3 build unexpectedly succeeded at the %s evidence boundary\n' "$label" >&2
    exit 1
  fi
  assert_no_artifacts "$output_dir"
  grep -Fq "v0.3.3 validation evidence is missing or invalid: $ps_evidence_input" "$output_file" || {
    printf 'v0.3.3 build did not report the exact missing/invalid evidence boundary for %s\n' "$label" >&2
    cat "$output_file" >&2
    exit 1
  }
  if grep -Fq 'permanent Task 6 placeholder' "$output_file" || grep -Fq 'remains gated until Task 6' "$output_file"; then
    printf 'v0.3.3 build still fails at the permanent Task 6 placeholder\n' >&2
    exit 1
  fi
}

run_evidence_boundary_case missing "$evidence_path"

invalid_evidence="$fixture_root/invalid-evidence.json"
"$python_cmd" - "$invalid_evidence" <<'PY'
import pathlib
import sys

pathlib.Path(sys.argv[1]).write_text('{"version":"0.3.3","cases":[]}', encoding="utf-8")
PY
run_evidence_boundary_case invalid "$invalid_evidence"

printf 'PASS: Windows v0.3.3 release-chain contract is present\n'
