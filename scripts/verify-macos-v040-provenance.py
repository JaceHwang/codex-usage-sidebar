#!/usr/bin/env python3
"""Bind published macOS 0.4.0 metadata and checksum to the release tag."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

tag, directory, app_directory = sys.argv[1:]
if tag != "v0.4.0":
    raise SystemExit("expected v0.4.0")
root = Path(directory)
commit = subprocess.check_output(["git", "rev-parse", f"{tag}^{{commit}}"], text=True).strip()
p = json.loads((root / "MACOS-V040-PROVENANCE.json").read_text())
assert p["version"] == "0.4.0"
assert p["sourceCommit"] == p["payloadCommit"] == commit
assert p["platform"] == "macos" and p["architecture"] == "arm64"
assert p["sdk"] == {"name": "macosx", "version": "26.5"}
assert p["asset"]["name"] == "codex-usage-sidebar-v0.4.0-macos-arm64.dmg"
assert hashlib.sha256((root / p["asset"]["name"]).read_bytes()).hexdigest() == p["asset"]["sha256"]
app = Path(app_directory)
assert (app / "Contents/Resources/InstallerPayloadCommit").read_text().strip() == commit
assert hashlib.sha256((app / "Contents/MacOS/CodexUsageSidebarInstaller").read_bytes()).hexdigest() == p["installer"]["executableSha256"]
companion = app / "Contents/Resources/payload/plugins/codex-usage-sidebar/assets/Codex Usage Sidebar.app/Contents/MacOS/CodexUsageSidebar"
assert hashlib.sha256(companion.read_bytes()).hexdigest() == p["companion"]["executableSha256"]
print("PASS: macOS asset provenance matches the exact release tag and SDK")
