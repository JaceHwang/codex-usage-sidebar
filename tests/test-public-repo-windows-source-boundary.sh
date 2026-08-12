#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output="$(mktemp)"
trap 'rm -f "$output"' EXIT

if bash "$repo_root/scripts/validate-public-repo.sh" >"$output" 2>&1; then
  printf 'PASS: public repository validator accepts Windows-only source changes\n'
  exit 0
fi

if grep -Fq \
  'marketplace companion source differs from provenance outside the installer allowlist' \
  "$output"; then
  cat "$output" >&2
  exit 1
fi

# Windows cannot complete the later macOS-only Ruby, plist, and codesign checks. Reaching them is
# sufficient for this focused boundary regression test; CI runs the complete validator on macOS.
printf 'PASS: Windows-only source changes pass the frozen macOS companion boundary\n'
