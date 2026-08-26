#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 2 ]]; then
  printf 'usage: %s APP DMG\n' "$0" >&2
  exit 64
fi

app="$1"
dmg="$2"
version="0.3.3"
expected_asset="codex-usage-sidebar-v0.3.3-macos-arm64.dmg"
mount_root=""

cleanup() {
  if [[ -n "$mount_root" ]]; then
    /usr/bin/hdiutil detach "$mount_root" >/dev/null 2>&1 || true
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
  local payload_commit="$candidate/Contents/Resources/InstallerPayloadCommit"

  [[ -d "$candidate" && -x "$executable" && -f "$manifest" && -f "$payload_provenance" \
      && -x "$companion" && -f "$payload_commit" ]] || {
    printf 'macOS v0.3.3 installer app is incomplete: %s\n' "$candidate" >&2
    exit 66
  }
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$candidate/Contents/Info.plist")" == "$version" ]]
  [[ "$(/usr/bin/lipo -archs "$executable")" == "arm64" ]]
  [[ "$(/usr/bin/lipo -archs "$companion")" == "arm64" ]]
  [[ "$(/bin/cat "$payload_commit")" =~ ^[0-9a-f]{40}$ ]]
  /usr/bin/codesign --verify --deep --strict "$candidate"
  /usr/bin/python3 - "$manifest" "$payload_provenance" "$companion" "$version" <<'PY'
import hashlib
import json
import sys

manifest_path, provenance_path, companion_path, version = sys.argv[1:]
manifest = json.load(open(manifest_path, encoding="utf-8"))
if manifest["version"].split("+", 1)[0] != version:
    raise SystemExit("embedded plugin version mismatch")
provenance = json.load(open(provenance_path, encoding="utf-8"))
digest = hashlib.sha256(open(companion_path, "rb").read()).hexdigest()
if digest != provenance["companion"]["executableSha256"]:
    raise SystemExit("embedded companion digest differs from provenance")
PY
}

[[ "$(/usr/bin/basename "$dmg")" == "$expected_asset" && -f "$dmg" ]] || {
  printf 'unexpected or missing macOS v0.3.3 DMG: %s\n' "$dmg" >&2
  exit 65
}
verify_app "$app"
/usr/bin/hdiutil verify "$dmg" >/dev/null
mount_root="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/cus-macos-v033-verify.XXXXXX")"
/usr/bin/hdiutil attach -nobrowse -readonly -mountpoint "$mount_root" "$dmg" >/dev/null
verify_app "$mount_root/Codex Usage Sidebar Installer.app"
/usr/bin/hdiutil detach "$mount_root" >/dev/null
/bin/rmdir "$mount_root"
mount_root=""
printf 'PASS: exact macOS v0.3.3 arm64 installer app and DMG are valid\n'
