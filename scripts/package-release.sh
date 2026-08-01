#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
plugin_root="$repo_root/plugins/codex-usage-sidebar"
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
/usr/bin/rsync -a \
  --exclude '.build/' \
  --exclude '.swiftpm/' \
  --exclude '.DS_Store' \
  "$plugin_root/" "$staging_root/codex-usage-sidebar/"
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
