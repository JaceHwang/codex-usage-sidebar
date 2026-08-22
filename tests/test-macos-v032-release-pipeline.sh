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
[[ "$base_version" == "0.3.2" ]] || {
  printf 'macOS v0.3.2 release pipeline requires plugin version 0.3.2, found %s\n' "$base_version" >&2
  exit 1
}

for script in \
  scripts/build-macos-v032-installer.sh \
  scripts/package-macos-v032-installer.sh \
  scripts/verify-macos-v032-installer-package.sh; do
  [[ -x "$repo_root/$script" ]] || {
    printf 'missing executable macOS v0.3.2 release script: %s\n' "$script" >&2
    exit 1
  }
done

combined="$(/bin/cat \
  "$repo_root/scripts/build-macos-v032-installer.sh" \
  "$repo_root/scripts/package-macos-v032-installer.sh" \
  "$repo_root/scripts/verify-macos-v032-installer-package.sh")"
for marker in \
  'version="0.3.2"' \
  'codex-usage-sidebar-v0.3.2-macos-arm64.dmg' \
  'MACOS-V032-SHA256SUMS.txt' \
  'MACOS-V032-PROVENANCE.json' \
  'InstallerPayloadCommit' \
  'codesign --verify --deep --strict' \
  'hdiutil verify' \
  'git -C "$repo_root" archive'; do
  [[ "$combined" == *"$marker"* ]] || {
    printf 'macOS v0.3.2 release pipeline is missing: %s\n' "$marker" >&2
    exit 1
  }
done

if [[ "$combined" == *'gh release'* ]]; then
  printf 'local macOS v0.3.2 packaging must not publish a GitHub release\n' >&2
  exit 1
fi

if [[ "$combined" == *'/^CDHash=/{print $2; exit}'* ]]; then
  printf 'macOS v0.3.2 build must consume codesign output without an early SIGPIPE under pipefail\n' >&2
  exit 1
fi

for frozen in \
  scripts/build-installer.sh \
  scripts/package-installer.sh \
  scripts/verify-installer-package.sh \
  scripts/finalize-installer-provenance.py \
  .github/workflows/publish-installer.yml; do
  git -C "$repo_root" diff --quiet HEAD -- "$frozen" || {
    printf 'frozen macOS v0.2.3 release file changed: %s\n' "$frozen" >&2
    exit 1
  }
done

for readme in README.md README.zh-CN.md; do
  grep -q 'codex-usage-sidebar-v0.3.2-macos-arm64.dmg' "$repo_root/$readme" || {
    printf 'README does not document the macOS v0.3.2 asset: %s\n' "$readme" >&2
    exit 1
  }
done

printf 'PASS: macOS v0.3.2 local release pipeline and README contract are present\n'
