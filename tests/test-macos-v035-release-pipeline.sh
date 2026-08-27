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
[[ "$base_version" == "0.3.5" ]] || {
  printf 'macOS v0.3.5 release pipeline requires plugin version 0.3.5, found %s\n' "$base_version" >&2
  exit 1
}

for script in \
  scripts/build-macos-v035-installer.sh \
  scripts/package-macos-v035-installer.sh \
  scripts/verify-macos-v035-installer-package.sh; do
  [[ -x "$repo_root/$script" ]] || {
    printf 'missing executable macOS v0.3.5 release script: %s\n' "$script" >&2
    exit 1
  }
done

combined="$(/bin/cat \
  "$repo_root/scripts/build-macos-v035-installer.sh" \
  "$repo_root/scripts/package-macos-v035-installer.sh" \
  "$repo_root/scripts/verify-macos-v035-installer-package.sh")"
for marker in \
  'version="0.3.5"' \
  'codex-usage-sidebar-v0.3.5-macos-arm64.dmg' \
  'MACOS-V035-SHA256SUMS.txt' \
  'MACOS-V035-PROVENANCE.json' \
  'InstallerPayloadCommit' \
  'codesign --verify --deep --strict' \
  'hdiutil verify' \
  'git -C "$repo_root" archive'; do
  [[ "$combined" == *"$marker"* ]] || {
    printf 'macOS v0.3.5 release pipeline is missing: %s\n' "$marker" >&2
    exit 1
  }
done

if [[ "$combined" == *'required_branch='* || "$combined" == *'branch --show-current'* ]]; then
  printf 'macOS v0.3.5 release pipeline must build from the exact selected commit, not a branch name\n' >&2
  exit 1
fi

if [[ "$combined" != *'provenance["sourceCommit"] != payload_commit'* ]]; then
  printf 'macOS v0.3.5 verifier must bind embedded companion provenance to InstallerPayloadCommit\n' >&2
  exit 1
fi

for document in README.md README.zh-CN.md docs/INSTALL.md docs/releases/v0.3.5.md; do
  grep -q 'codex-usage-sidebar-v0.3.5-macos-arm64.dmg' "$repo_root/$document" || {
    printf 'v0.3.5 macOS release documentation is missing the DMG asset: %s\n' "$document" >&2
    exit 1
  }
done

for document in README.md README.zh-CN.md docs/INSTALL.md; do
  grep -q 'codex-usage-sidebar-v0.3.3-windows-x64-setup.exe' "$repo_root/$document" || {
    printf 'v0.3.5 documentation must preserve the v0.3.3 Windows release reference: %s\n' "$document" >&2
    exit 1
  }
done

printf 'PASS: macOS v0.3.5 pipeline and platform-specific documentation contract are present\n'
