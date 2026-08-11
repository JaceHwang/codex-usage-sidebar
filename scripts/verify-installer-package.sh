#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 2 ]]; then
  printf 'usage: %s APP DMG\n' "$0" >&2
  exit 64
fi

app="$1"
dmg="$2"
expected_asset="codex-usage-sidebar-v0.2.3-macos-arm64.dmg"
mount_root=""

cleanup() {
  if [[ -n "$mount_root" ]]; then
    /usr/sbin/diskutil eject "$mount_root" >/dev/null 2>&1 || true
    /bin/rmdir "$mount_root" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

verify_app() {
  local candidate="$1"
  local executable="$candidate/Contents/MacOS/CodexUsageSidebarInstaller"
  local payload="$candidate/Contents/Resources/payload/plugins/codex-usage-sidebar"
  local manifest="$payload/.codex-plugin/plugin.json"
  local payload_provenance="$payload/assets/PROVENANCE.json"
  local companion="$payload/assets/Codex Usage Sidebar.app/Contents/MacOS/CodexUsageSidebar"

  [[ -d "$candidate" ]] || { printf 'installer app is missing: %s\n' "$candidate" >&2; exit 66; }
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$candidate/Contents/Info.plist")" == "0.2.3" ]] || {
    printf 'installer app version is not 0.2.3: %s\n' "$candidate" >&2
    exit 65
  }
  [[ -f "$manifest" ]] || { printf 'embedded plugin manifest is missing\n' >&2; exit 66; }
  [[ -f "$payload_provenance" ]] || { printf 'embedded payload provenance is missing\n' >&2; exit 66; }
  [[ -x "$companion" ]] || { printf 'embedded companion is missing\n' >&2; exit 66; }
  [[ -x "$executable" ]] || { printf 'installer executable is missing\n' >&2; exit 66; }
  [[ "$(/usr/bin/lipo -archs "$executable")" == "arm64" ]] || {
    printf 'installer executable is not arm64-only\n' >&2
    exit 65
  }
  /usr/bin/codesign --verify --deep --strict "$candidate"
  /usr/bin/python3 - "$manifest" "$payload_provenance" "$companion" <<'PY'
import hashlib
import json
import sys

manifest_path, provenance_path, companion_path = sys.argv[1:]
manifest = json.load(open(manifest_path, encoding="utf-8"))
if manifest["version"].split("+", 1)[0] != "0.2.3":
    raise SystemExit("embedded plugin version is not 0.2.3")
provenance = json.load(open(provenance_path, encoding="utf-8"))
hasher = hashlib.sha256()
with open(companion_path, "rb") as handle:
    for chunk in iter(lambda: handle.read(1024 * 1024), b""):
        hasher.update(chunk)
digest = hasher.hexdigest()
if digest != provenance["companion"]["executableSha256"]:
    raise SystemExit("embedded companion digest differs from provenance")
PY
}

[[ "$(/usr/bin/basename "$dmg")" == "$expected_asset" ]] || {
  printf 'unexpected installer asset name: %s\n' "$(/usr/bin/basename "$dmg")" >&2
  exit 65
}
[[ -f "$dmg" ]] || { printf 'installer DMG is missing: %s\n' "$dmg" >&2; exit 66; }
verify_app "$app"
/usr/bin/hdiutil verify "$dmg" >/dev/null

mount_root="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/cus-installer-verify.XXXXXX")"
/usr/sbin/diskutil image attach \
  --nobrowse \
  --readOnly \
  --mountPoint "$mount_root" \
  "$dmg" >/dev/null
mounted_app="$mount_root/Codex Usage Sidebar Installer.app"
verify_app "$mounted_app"
/usr/sbin/diskutil eject "$mount_root" >/dev/null
/bin/rmdir "$mount_root"
mount_root=""

printf 'PASS: installer app and exact v0.2.3 arm64 DMG are valid\n'
