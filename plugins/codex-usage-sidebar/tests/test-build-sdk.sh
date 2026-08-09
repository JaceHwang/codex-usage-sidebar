#!/usr/bin/env bash
set -euo pipefail

plugin_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
executable="$plugin_root/assets/Codex Usage Sidebar.app/Contents/MacOS/CodexUsageSidebar"

[[ -x "$executable" ]] || {
  printf 'companion executable is missing: %s\n' "$executable" >&2
  exit 66
}

architectures="$(/usr/bin/lipo -archs "$executable")"
[[ " $architectures " == *" arm64 "* ]] || {
  printf 'companion must contain arm64; found: %s\n' "$architectures" >&2
  exit 65
}

sdk_version="$(/usr/bin/otool -l "$executable" | /usr/bin/awk '
  $1 == "cmd" && $2 == "LC_BUILD_VERSION" { in_build = 1; next }
  in_build && $1 == "sdk" { print $2; exit }
')"
[[ "$sdk_version" == "26.5" ]] || {
  printf 'companion must be linked with macOS SDK 26.5; found: %s\n' "$sdk_version" >&2
  exit 65
}

printf 'PASS: companion is arm64 and linked with macOS SDK %s\n' "$sdk_version"
