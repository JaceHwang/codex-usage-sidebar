#!/usr/bin/env bash
set -euo pipefail

plugin_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest="$plugin_root/.codex-plugin/plugin.json"
info_plist="$plugin_root/assets/Codex Usage Sidebar.app/Contents/Info.plist"

manifest_version="$(
  /usr/bin/python3 -c \
    'import json,sys; print(json.load(open(sys.argv[1]))["version"])' \
    "$manifest"
)"
expected_version="${manifest_version%%+*}"
bundle_version="$(
  /usr/libexec/PlistBuddy \
    -c 'Print :CFBundleShortVersionString' \
    "$info_plist"
)"

[[ "$bundle_version" == "$expected_version" ]] || {
  printf 'FAIL: manifest version %s produced bundle version %s\n' \
    "$manifest_version" \
    "$bundle_version" >&2
  exit 1
}

printf 'PASS: manifest and companion bundle versions match at %s\n' \
  "$bundle_version"
