#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

python3 - <<'PY'
import json
import plistlib
import xml.etree.ElementTree as ET
from pathlib import Path

root = Path.cwd()
expected = (root / "version.txt").read_text().split()[0]

manifest = json.loads((root / ".release-please-manifest.json").read_text())
assert manifest == {".": expected}, manifest
assert expected.count(".") == 2 and all(part.isdecimal() for part in expected.split(".")), expected

plugin = json.loads((root / "plugins/codex-usage-sidebar/.codex-plugin/plugin.json").read_text())
assert plugin["version"].split("+", 1)[0] == expected, plugin["version"]

with (root / "plugins/codex-usage-sidebar/assets/Codex Usage Sidebar.app/Contents/Info.plist").open("rb") as handle:
    plist = plistlib.load(handle)
assert plist["CFBundleShortVersionString"] == expected

xml = ET.parse(root / "plugins/codex-usage-sidebar/windows/Directory.Build.props")
assert xml.findtext(".//VersionPrefix") == expected

config = json.loads((root / "release-please-config.json").read_text())
package = config["packages"]["."]
assert package["component"] == "codex-usage-sidebar"
extra = {(item["path"], item["type"]) for item in package["extra-files"]}
assert ("plugins/codex-usage-sidebar/.codex-plugin/plugin.json", "json") in extra
assert ("version.txt", "generic") in extra
assert ("plugins/codex-usage-sidebar/assets/Codex Usage Sidebar.app/Contents/Info.plist", "xml") in extra
assert ("plugins/codex-usage-sidebar/windows/Directory.Build.props", "xml") in extra

for channel in ("alpha", "beta", "rc"):
    prerelease = json.loads((root / ".governance/release" / f"{channel}.json").read_text())
    assert prerelease["versioning"] == "prerelease"
    assert prerelease["packages"]["."]["prerelease-type"] == channel
PY

grep -q '^RELEASE_MODE=staged$' .governance/policy.sh
grep -q "^RELEASE_PLATFORMS='macos-arm64 windows-x64'$" .governance/policy.sh
grep -q '^FAST_CHECK_ADAPTER=.governance/project/check-fast$' .governance/policy.sh
grep -q '^FULL_CHECK_ADAPTER=.governance/project/check-full$' .governance/policy.sh

test -x .governance/project/check-fast
test -x .governance/project/check-full

printf 'repository governance integration tests passed\n'
