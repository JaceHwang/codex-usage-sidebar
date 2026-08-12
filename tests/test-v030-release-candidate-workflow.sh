#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workflow="$repo_root/.github/workflows/v030-release-candidates.yml"
[[ -f "$workflow" ]] || { printf 'missing v0.3.0 candidate workflow\n' >&2; exit 1; }

python3 - "$workflow" <<'PY'
import sys
from pathlib import Path

workflow = Path(sys.argv[1]).read_text(encoding="utf-8")
required = (
    "branches: [v0.3.0]",
    "permissions:\n  contents: read",
    "runs-on: windows-2025",
    "runs-on: macos-26",
    "DEVELOPER_DIR: /Applications/Xcode_26.5.app/Contents/Developer",
    "docs/validation/windows-v0.3.0.json",
    "scripts/build-windows-v030-setup.ps1",
    "scripts/verify-windows-v030-setup.ps1",
    "scripts/build-macos-v030-installer.sh",
    "scripts/package-macos-v030-installer.sh",
    "scripts/verify-macos-v030-installer-package.sh",
    "scripts/finalize-windows-v030-provenance.py",
    "scripts/finalize-macos-v030-provenance.py",
    "codex-usage-sidebar-v0.3.0-windows-x64-candidate",
    "codex-usage-sidebar-v0.3.0-macos-arm64-candidate",
    "codex-usage-sidebar-v0.3.0-windows-x64-provenance",
    "codex-usage-sidebar-v0.3.0-macos-arm64-provenance",
)
for marker in required:
    if marker not in workflow:
        raise SystemExit(f"v0.3.0 candidate workflow is missing: {marker}")

for forbidden in (
    "contents: write",
    "gh release",
    "softprops/action-gh-release",
    "release create",
    "codex-usage-sidebar-v0.2.3-macos-arm64.dmg",
    "win-arm64",
    "windows-arm64",
):
    if forbidden.lower() in workflow.lower():
        raise SystemExit(f"v0.3.0 candidate workflow contains forbidden publication or asset marker: {forbidden}")
PY

printf 'PASS: exact v0.3.0 workflow builds Windows x64 and macOS arm64 candidates without publishing\n'
