#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest="$repo_root/plugins/codex-usage-sidebar/.codex-plugin/plugin.json"

base_version="$(/usr/bin/python3 - "$manifest" <<'PY'
import json
import sys

print(json.load(open(sys.argv[1], encoding="utf-8"))["version"].split("+", 1)[0])
PY
)"
[[ "$base_version" == "0.3.3" ]] || {
  printf 'macOS v0.3.3 release pipeline requires plugin version 0.3.3, found %s\n' "$base_version" >&2
  exit 1
}

for script in \
  scripts/build-macos-v033-installer.sh \
  scripts/package-macos-v033-installer.sh \
  scripts/verify-macos-v033-installer-package.sh; do
  [[ -x "$repo_root/$script" ]] || {
    printf 'missing executable macOS v0.3.3 release script: %s\n' "$script" >&2
    exit 1
  }
done

combined="$(/bin/cat \
  "$repo_root/scripts/build-macos-v033-installer.sh" \
  "$repo_root/scripts/package-macos-v033-installer.sh" \
  "$repo_root/scripts/verify-macos-v033-installer-package.sh")"
for marker in \
  'version="0.3.3"' \
  'codex-usage-sidebar-v0.3.3-macos-arm64.dmg' \
  'MACOS-V033-SHA256SUMS.txt' \
  'MACOS-V033-PROVENANCE.json' \
  'InstallerPayloadCommit' \
  'codesign --verify --deep --strict' \
  'hdiutil verify' \
  'git -C "$repo_root" archive'; do
  [[ "$combined" == *"$marker"* ]] || {
    printf 'macOS v0.3.3 release pipeline is missing: %s\n' "$marker" >&2
    exit 1
  }
done

if [[ "$combined" == *'required_branch='* || "$combined" == *'branch --show-current'* ]]; then
  printf 'macOS v0.3.3 release pipeline must build from the exact selected commit, not a branch name\n' >&2
  exit 1
fi

for document in README.md README.zh-CN.md docs/INSTALL.md docs/releases/v0.3.3.md; do
  grep -q 'codex-usage-sidebar-v0.3.3-macos-arm64.dmg' "$repo_root/$document" || {
    printf 'v0.3.3 macOS release documentation is missing the DMG asset: %s\n' "$document" >&2
    exit 1
  }
done

printf 'PASS: macOS v0.3.3 branch-independent release pipeline and documentation contract are present\n'
