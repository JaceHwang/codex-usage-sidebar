#!/usr/bin/env python3
"""Require one promoted v0.3.0 identity while preserving frozen v0.2.3 assets."""

from __future__ import annotations

import json
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
VERSION = "0.3.0"
sys.path.insert(0, str(ROOT / "scripts"))
from v030_release_profiles import FORMAL, QUICK_PRERELEASE, profile


def text(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


branch = subprocess.check_output(
    ["git", "-C", str(ROOT), "branch", "--show-current"], text=True
).strip()
if branch != "v0.3.0":
    raise SystemExit(f"release branch must be exactly v0.3.0, found {branch}")

if FORMAL != {
    "releaseProfile": "formal",
    "tag": "v0.3.0",
    "evidencePath": "docs/validation/windows-v0.3.0.json",
    "realDeviceValidated": True,
}:
    raise SystemExit("formal v0.3.0 release profile changed")
if QUICK_PRERELEASE != {
    "releaseProfile": "quick-prerelease",
    "tag": "v0.3.0-rc.1",
    "evidencePath": "docs/validation/windows-v0.3.0-quick-prerelease.json",
    "realDeviceValidated": False,
}:
    raise SystemExit("v0.3.0 rc.1 quick prerelease profile is inconsistent")
quick_profile_copy = profile("quick-prerelease")
quick_profile_copy["tag"] = "unexpected"
if profile("quick-prerelease") != {
    "releaseProfile": "quick-prerelease",
    "tag": "v0.3.0-rc.1",
    "evidencePath": "docs/validation/windows-v0.3.0-quick-prerelease.json",
    "realDeviceValidated": False,
}:
    raise SystemExit("release profile lookup leaked a mutable canonical descriptor")

manifest = json.loads(text("plugins/codex-usage-sidebar/.codex-plugin/plugin.json"))
match = re.fullmatch(r"0\.3\.0\+codex\.(\d{14})", manifest.get("version", ""))
if match is None or match.group(1) < "20260813000000":
    raise SystemExit("plugin manifest needs a fresh v0.3.0 cache-buster")

props = ET.fromstring(text("plugins/codex-usage-sidebar/windows/Directory.Build.props"))
prefixes = [element.text for element in props.iter("VersionPrefix")]
suffixes = [element.text for element in props.iter("VersionSuffix") if element.text]
if prefixes != [VERSION] or suffixes:
    raise SystemExit("Windows assemblies must use unsuffixed VersionPrefix 0.3.0")

windows_release_files = (
    "scripts/install-windows-device-payload.ps1",
    "scripts/build-windows-payload-manifest.py",
    "scripts/verify-windows-payload.py",
    "plugins/codex-usage-sidebar/scripts/sidebar-control-windows.ps1",
    "plugins/codex-usage-sidebar/windows/src/CodexUsageSidebar.Windows/WpfOverlaySurface.cs",
    "plugins/codex-usage-sidebar/windows/src/CodexUsageSidebar.Windows/WindowsHostApplication.cs",
    "plugins/codex-usage-sidebar/windows/src/CodexUsageSidebar.Installer/InstallerApplication.cs",
    "plugins/codex-usage-sidebar/windows/src/CodexUsageSidebar.Installer/InstallerUiController.cs",
    "plugins/codex-usage-sidebar/windows/src/CodexUsageSidebar.Installer/DevicePayloadInstallPlan.cs",
)
for relative in windows_release_files:
    contents = text(relative)
    if "0.3.0-beta.1" in contents:
        raise SystemExit(f"active Windows release file still contains beta version: {relative}")

macos_release_files = (
    "plugins/codex-usage-sidebar/native/Sources/InstallerCore/PayloadInstaller.swift",
    "plugins/codex-usage-sidebar/native/Sources/InstallerCore/InstallerPresentation.swift",
    "plugins/codex-usage-sidebar/native/Sources/CodexUsageSidebarInstaller/InstallerViewModel.swift",
)
for relative in macos_release_files:
    if "0.2.3" in text(relative):
        raise SystemExit(f"active macOS installer source still contains v0.2.3: {relative}")

frozen_info = text(
    "plugins/codex-usage-sidebar/assets/Codex Usage Sidebar.app/Contents/Info.plist"
)
if "<string>0.2.3</string>" not in frozen_info or "<string>0.3.0</string>" in frozen_info:
    raise SystemExit("frozen repository macOS companion asset was modified")
for relative in (
    "scripts/build-installer.sh",
    "scripts/package-installer.sh",
    "scripts/verify-installer-package.sh",
    "scripts/finalize-installer-provenance.py",
):
    if "0.2.3" not in text(relative):
        raise SystemExit(f"frozen v0.2.3 release boundary disappeared: {relative}")

release_notes = ROOT / "docs/releases/v0.3.0.md"
if not release_notes.is_file() or "Windows x64" not in release_notes.read_text(encoding="utf-8") \
        or "macOS arm64" not in release_notes.read_text(encoding="utf-8"):
    raise SystemExit("v0.3.0 release notes must cover Windows x64 and macOS arm64")

for relative in ("README.md", "README.zh-CN.md"):
    contents = text(relative)
    if "v0.3.0-beta.1" in contents or "codex/v0.3.0-beta.1" in contents:
        raise SystemExit(f"current project status still points at the beta branch: {relative}")
    if "v0.3.0" not in contents or "Windows ARM64" not in contents:
        raise SystemExit(f"current v0.3.0 Windows x64 scope is missing: {relative}")

print("PASS: v0.3.0 versions are consistent and frozen v0.2.3 assets remain intact")
