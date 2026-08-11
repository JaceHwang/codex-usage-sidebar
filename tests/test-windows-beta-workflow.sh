#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workflow="$repo_root/.github/workflows/windows-beta.yml"

[[ -f "$workflow" ]]
grep -Fq 'runs-on: windows-2025' "$workflow"
grep -Fq 'dotnet test plugins/codex-usage-sidebar/windows/CodexUsageSidebar.Windows.sln' "$workflow"
grep -Fq 'CodexUsageSidebar.Control.exe' "$workflow"
grep -Fq 'codex-usage-sidebar-v0.3.0-beta.1-windows-x64-diagnostic.zip' "$workflow"
grep -Fq 'WINDOWS-BETA-PROVENANCE.json' "$workflow"
grep -Fq 'WINDOWS-BETA-SHA256SUMS.txt' "$workflow"

if grep -Eq 'gh release|softprops/action-gh-release|contents:[[:space:]]*write' "$workflow"; then
  printf 'Windows beta workflow must not publish a release before real-device validation\n' >&2
  exit 1
fi

printf 'PASS: Windows beta workflow builds only a diagnostic candidate\n'
