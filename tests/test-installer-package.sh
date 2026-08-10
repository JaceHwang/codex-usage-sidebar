#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dist="$repo_root/.dist"
app="$dist/installer/Codex Usage Sidebar Installer.app"
dmg="$dist/codex-usage-sidebar-v0.2.3-macos-arm64.dmg"
checksums="$dist/INSTALLER-SHA256SUMS.txt"
provenance="$dist/INSTALLER-PROVENANCE.json"

[[ -x "$repo_root/scripts/build-installer.sh" ]]
[[ -x "$repo_root/scripts/package-installer.sh" ]]

DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}" \
  "$repo_root/scripts/build-installer.sh"
"$repo_root/scripts/package-installer.sh"

[[ -d "$app" ]]
[[ -f "$dmg" ]]
[[ -f "$checksums" ]]
[[ -f "$provenance" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")" == "0.2.3" ]]
[[ "$(/usr/bin/python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"].split("+")[0])' "$app/Contents/Resources/payload/plugins/codex-usage-sidebar/.codex-plugin/plugin.json")" == "0.2.3" ]]

/usr/bin/codesign --verify --deep --strict "$app"
[[ "$(/usr/bin/lipo -archs "$app/Contents/MacOS/CodexUsageSidebarInstaller")" == "arm64" ]]
/usr/bin/hdiutil verify "$dmg" >/dev/null
(cd "$dist" && /usr/bin/shasum -a 256 -c "$(basename "$checksums")")

mount_root="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/cus-installer-mount.XXXXXX")"
cleanup() {
  /usr/sbin/diskutil eject "$mount_root" >/dev/null 2>&1 || true
  /bin/rmdir "$mount_root" >/dev/null 2>&1 || true
}
trap cleanup EXIT
/usr/sbin/diskutil image attach \
  --nobrowse \
  --readOnly \
  --mountPoint "$mount_root" \
  "$dmg" >/dev/null
mounted_app="$mount_root/Codex Usage Sidebar Installer.app"
[[ -d "$mounted_app" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$mounted_app/Contents/Info.plist")" == "0.2.3" ]]

if /usr/bin/find "$mounted_app/Contents/Resources/payload" \
  \( -name .git -o -name .build -o -name .dist -o -name .DS_Store -o -name __MACOSX \) \
  -print -quit | /usr/bin/grep -q .; then
  echo "installer payload contains repository or generated metadata" >&2
  exit 1
fi

/usr/bin/python3 - "$provenance" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1]))
assert data["schemaVersion"] == 1
assert data["version"] == "0.2.3"
assert data["asset"]["name"] == "codex-usage-sidebar-v0.2.3-macos-arm64.dmg"
assert data["platform"] == "macos"
assert data["architecture"] == "arm64"
assert data["notarized"] is False
PY

printf 'PASS: v0.2.3 macOS arm64 installer app and DMG are valid\n'
