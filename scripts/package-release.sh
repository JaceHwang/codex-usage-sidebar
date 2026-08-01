#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
plugin_root="$repo_root/plugins/codex-usage-sidebar"
plugin_relative="plugins/codex-usage-sidebar"
version="$(/usr/bin/python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"].split("+")[0])' "$plugin_root/.codex-plugin/plugin.json")"
dist="$repo_root/.dist"
archive="$dist/codex-usage-sidebar-v$version.zip"
checksums="$dist/SHA256SUMS.txt"
staging_root=""

cleanup() {
  if [[ -n "$staging_root" && -d "$staging_root" && "$staging_root" == "$dist"/.package.* ]]; then
    /bin/rm -rf "$staging_root"
  fi
}
trap cleanup EXIT

/bin/mkdir -p "$dist"
staging_root="$(/usr/bin/mktemp -d "$dist/.package.XXXXXX")"
/bin/mkdir -p "$staging_root/codex-usage-sidebar"

if ! /usr/bin/git -C "$repo_root" diff --quiet HEAD -- "$plugin_relative" \
  ':(exclude)plugins/codex-usage-sidebar/assets/Codex Usage Sidebar.app'; then
  printf 'tracked plugin source differs from HEAD; commit it before packaging\n' >&2
  exit 65
fi
if [[ -n "$(/usr/bin/git -C "$repo_root" ls-files --others --exclude-standard -- "$plugin_relative")" ]]; then
  printf 'untracked plugin payload files are present; remove or commit them before packaging\n' >&2
  exit 65
fi

/usr/bin/git -C "$repo_root" archive --format=tar "HEAD:$plugin_relative" |
  /usr/bin/tar -xf - -C "$staging_root/codex-usage-sidebar"
/bin/rm -rf "$staging_root/codex-usage-sidebar/assets/Codex Usage Sidebar.app"
/usr/bin/ditto \
  "$plugin_root/assets/Codex Usage Sidebar.app" \
  "$staging_root/codex-usage-sidebar/assets/Codex Usage Sidebar.app"
/usr/bin/codesign --verify --deep --strict \
  "$staging_root/codex-usage-sidebar/assets/Codex Usage Sidebar.app"
/bin/rm -f "$archive"
(
  cd "$staging_root"
  /usr/bin/zip -q -r -X "$archive" codex-usage-sidebar
)
(
  cd "$dist"
  /usr/bin/shasum -a 256 "$(basename "$archive")" >"$(basename "$checksums")"
)
printf 'Created %s\nCreated %s\n' "$archive" "$checksums"
