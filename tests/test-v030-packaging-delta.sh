#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
verifier="$repo_root/scripts/verify-v030-packaging-delta.py"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT

git -C "$fixture" init -q
git -C "$fixture" config user.name fixture
git -C "$fixture" config user.email fixture@example.invalid
printf 'source\n' >"$fixture/code.txt"
mkdir -p "$fixture/docs/validation"
printf 'pending\n' >"$fixture/docs/validation/windows-v0.3.0.json"
git -C "$fixture" add .
git -C "$fixture" commit -qm source
validated="$(git -C "$fixture" rev-parse HEAD)"

printf 'passed\n' >"$fixture/docs/validation/windows-v0.3.0.json"
git -C "$fixture" add docs/validation/windows-v0.3.0.json
git -C "$fixture" commit -qm evidence
packaging="$(git -C "$fixture" rev-parse HEAD)"

python3 "$verifier" \
  --repository "$fixture" \
  --validated-source-commit "$validated" \
  --packaging-commit "$packaging" \
  --allowed-path docs/validation/windows-v0.3.0.json

printf 'changed code\n' >"$fixture/code.txt"
git -C "$fixture" add code.txt
git -C "$fixture" commit -qm code-change
unexpected="$(git -C "$fixture" rev-parse HEAD)"
if python3 "$verifier" \
  --repository "$fixture" \
  --validated-source-commit "$validated" \
  --packaging-commit "$unexpected" \
  --allowed-path docs/validation/windows-v0.3.0.json >/dev/null 2>&1; then
  printf 'post-validation source change unexpectedly passed packaging delta gate\n' >&2
  exit 1
fi

if python3 "$verifier" \
  --repository "$fixture" \
  --validated-source-commit "$unexpected" \
  --packaging-commit "$validated" \
  --allowed-path docs/validation/windows-v0.3.0.json >/dev/null 2>&1; then
  printf 'non-ancestor validated source unexpectedly passed packaging delta gate\n' >&2
  exit 1
fi

printf 'PASS: v0.3.0 packaging commit may differ from validated source only by evidence\n'
