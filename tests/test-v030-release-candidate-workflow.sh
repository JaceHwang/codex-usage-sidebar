#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workflow="$repo_root/.github/workflows/v030-release-candidates.yml"
[[ -f "$workflow" ]] || { printf 'missing v0.3.0 candidate workflow\n' >&2; exit 1; }

python3 - "$workflow" <<'PY'
import sys
from pathlib import Path
import re

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
    "release-bundle:",
    "needs: [windows-x64, macos-arm64]",
    "runs-on: ubuntu-24.04",
    "actions/download-artifact@37930b1c2abaa49bbe596cd826c3c89aef350131",
    "scripts/verify-v030-candidate-set.py",
    "codex-usage-sidebar-v0.3.0-release-bundle",
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

release_job_match = re.search(r"(?ms)^  release-bundle:\n(?P<body>.*)\Z", workflow)
if release_job_match is None:
    raise SystemExit("v0.3.0 candidate workflow lacks the release-bundle job")
release_job = release_job_match.group("body")

downloads = (
    ("codex-usage-sidebar-v0.3.0-windows-x64-candidate", "windows-candidate"),
    ("codex-usage-sidebar-v0.3.0-windows-x64-provenance", "windows-provenance"),
    ("codex-usage-sidebar-v0.3.0-macos-arm64-candidate", "macos-candidate"),
    ("codex-usage-sidebar-v0.3.0-macos-arm64-provenance", "macos-provenance"),
)
download_pin = "actions/download-artifact@37930b1c2abaa49bbe596cd826c3c89aef350131"
if release_job.count(download_pin) != len(downloads):
    raise SystemExit("release-bundle must use the pinned download action exactly four times")
for artifact, directory in downloads:
    pattern = rf"(?ms)uses: {re.escape(download_pin)}[^\n]*\n\s+with:\n\s+name: {re.escape(artifact)}\n\s+path: \$\{{\{{ runner\.temp \}}\}}/v030-downloads/{directory}(?:\n|$)"
    if re.search(pattern, release_job) is None:
        raise SystemExit(f"release-bundle lacks an isolated download for: {artifact}")
for guard in (
    'test ! -L "$directory"',
    'actual_count="$(find "$directory" -mindepth 1 -maxdepth 1 -printf \'x\' | wc -c)"',
    'test "$actual_count" -eq "$#"',
):
    if guard not in release_job:
        raise SystemExit(f"release-bundle lacks exact artifact input validation: {guard}")

expected_release_files = {
    "codex-usage-sidebar-v0.3.0-windows-x64-setup.exe",
    "WINDOWS-V030-SHA256SUMS.txt",
    "WINDOWS-V030-PROVENANCE.final.json",
    "codex-usage-sidebar-v0.3.0-macos-arm64.dmg",
    "MACOS-V030-SHA256SUMS.txt",
    "MACOS-V030-PROVENANCE.final.json",
}
upload_match = re.search(
    r"(?ms)uses: actions/upload-artifact@b7c566a772e6b6bfb58ed0dc250532a479d7789f[^\n]*\n"
    r"\s+with:\n"
    r"\s+name: codex-usage-sidebar-v0\.3\.0-release-bundle\n"
    r"\s+path: \|\n(?P<paths>(?:\s{12}.+\n)+)"
    r"\s+if-no-files-found: error(?:\n|$)",
    release_job,
)
if upload_match is None:
    raise SystemExit("release-bundle lacks the pinned explicit six-file upload")
uploaded_paths = {
    line.strip().removeprefix("${{ runner.temp }}/release-bundle/")
    for line in upload_match.group("paths").splitlines()
}
if uploaded_paths != expected_release_files or len(upload_match.group("paths").splitlines()) != 6:
    raise SystemExit("release-bundle upload path must contain exactly the six final release filenames")
if "V030-RELEASE-SUMMARY.json" in upload_match.group("paths"):
    raise SystemExit("release verification summary must not be uploaded as a release asset")
PY

printf 'PASS: exact v0.3.0 workflow builds Windows x64 and macOS arm64 candidates without publishing\n'
