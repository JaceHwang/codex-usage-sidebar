#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_root="$(mktemp -d)"
trap 'rm -rf "$fixture_root"' EXIT

plan="$(pwsh -NoProfile -File "$repo_root/scripts/build-windows-v033-setup.ps1" -PlanOnly)"
PLAN="$plan" /usr/bin/python3 - <<'PY'
import json
import os

plan = json.loads(os.environ["PLAN"])
assert plan["version"] == "0.3.3"
assert plan["architecture"] == "x64"
assert plan["selectorsSchemaVersion"] == 2
assert plan["publishableInstaller"] is False
PY

/usr/bin/python3 - "$repo_root/scripts/v033_release_profiles.py" <<'PY'
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
output_file="$fixture_root/output.txt"
if pwsh -NoProfile -File "$repo_root/scripts/build-windows-v033-setup.ps1" \
  -ValidationEvidence "$fixture_root/evidence.json" -OutputDirectory "$fixture_root/out" \
  -CompatibilityPublicKey "$valid_spki" -CompatibilityUpdateUri https://example.invalid/pack.zip \
  >"$output_file" 2>&1; then
  printf 'v0.3.3 build unexpectedly succeeded without evidence validation\n' >&2
  exit 1
fi
if grep -Fq 'permanent Task 6 placeholder' "$output_file" || grep -Fq 'remains gated until Task 6' "$output_file"; then
  printf 'v0.3.3 build still fails at the permanent Task 6 placeholder\n' >&2
  exit 1
fi
grep -Eiq 'source|evidence|validation' "$output_file" || {
  printf 'v0.3.3 build did not reach source/evidence validation\n' >&2
  exit 1
}

printf 'PASS: Windows v0.3.3 release-chain contract is present\n'
