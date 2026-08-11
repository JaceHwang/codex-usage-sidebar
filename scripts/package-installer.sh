#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dist="$repo_root/.dist"
app="$dist/installer/Codex Usage Sidebar Installer.app"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
asset_name="codex-usage-sidebar-v$version-macos-arm64.dmg"
dmg="$dist/$asset_name"
checksums="$dist/INSTALLER-SHA256SUMS.txt"
provenance="$dist/INSTALLER-PROVENANCE.json"
staging_root=""

cleanup() {
  if [[ -n "$staging_root" && "$staging_root" == "$dist"/.installer-package.* ]]; then
    /bin/rm -rf "$staging_root"
  fi
}
trap cleanup EXIT

if [[ "$version" != "0.2.3" || "$asset_name" != "codex-usage-sidebar-v0.2.3-macos-arm64.dmg" ]]; then
  printf 'refusing installer asset version mismatch: %s\n' "$asset_name" >&2
  exit 65
fi
[[ -d "$app" ]] || { printf 'installer app is missing: %s\n' "$app" >&2; exit 66; }
/usr/bin/codesign --verify --deep --strict "$app"
payload_ref="${CUS_INSTALLER_PAYLOAD_REF:-HEAD}"
requested_payload_commit="$(/usr/bin/git -C "$repo_root" rev-parse "$payload_ref^{commit}")"
payload_marker="$app/Contents/Resources/InstallerPayloadCommit"
[[ -f "$payload_marker" ]] || {
  printf 'installer payload commit marker is missing: %s\n' "$payload_marker" >&2
  exit 67
}
payload_commit="$(/bin/cat "$payload_marker")"
if [[ ! "$payload_commit" =~ ^[0-9a-f]{40}$ || "$payload_commit" != "$requested_payload_commit" ]]; then
  printf 'installer payload commit mismatch: built %s, requested %s\n' \
    "$payload_commit" "$requested_payload_commit" >&2
  exit 67
fi

/bin/mkdir -p "$dist"
staging_root="$(/usr/bin/mktemp -d "$dist/.installer-package.XXXXXX")"
/usr/bin/ditto "$app" "$staging_root/Codex Usage Sidebar Installer.app"
/bin/cat >"$staging_root/首次打开说明.txt" <<'TEXT'
Codex Usage Sidebar v0.2.3

1. 双击“Codex Usage Sidebar Installer”。
2. 如果 macOS 阻止打开，请在 Finder 中右键安装器并选择“打开”。
3. 点击“安装”，按引导完成 Codex 登录和辅助功能授权。

English:
1. Open “Codex Usage Sidebar Installer”.
2. If macOS blocks this raw asset, right-click the installer in Finder and choose Open.
3. Click Install, then finish Codex login and Accessibility authorization.
TEXT

/bin/rm -f "$dmg" "$checksums" "$provenance"
/usr/sbin/diskutil image create from \
  --volumeName "Codex Usage Sidebar v$version" \
  --format UDZO \
  "$staging_root" \
  "$dmg" >/dev/null
/usr/bin/hdiutil verify "$dmg" >/dev/null
"$repo_root/scripts/verify-installer-package.sh" "$app" "$dmg"

(
  cd "$dist"
  /usr/bin/shasum -a 256 "$asset_name" >"$(basename "$checksums")"
)

source_commit="$(/usr/bin/git -C "$repo_root" rev-parse HEAD)"
dmg_sha="$(/usr/bin/shasum -a 256 "$dmg" | /usr/bin/awk '{print $1}')"
installer_sha="$(/usr/bin/shasum -a 256 "$app/Contents/MacOS/CodexUsageSidebarInstaller" | /usr/bin/awk '{print $1}')"
companion="$app/Contents/Resources/payload/plugins/codex-usage-sidebar/assets/Codex Usage Sidebar.app/Contents/MacOS/CodexUsageSidebar"
companion_sha="$(/usr/bin/shasum -a 256 "$companion" | /usr/bin/awk '{print $1}')"
sdk_version="$(
  DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}" \
    /usr/bin/xcrun --sdk macosx --show-sdk-version
)"
signature="adhoc"
if /usr/bin/codesign -dv --verbose=4 "$app" 2>&1 | /usr/bin/grep -q '^TeamIdentifier='; then
  signature="developer-id"
fi

/usr/bin/python3 - \
  "$provenance" "$asset_name" "$dmg_sha" "$installer_sha" "$companion_sha" \
  "$source_commit" "$payload_ref" "$payload_commit" "$signature" "$sdk_version" <<'PY'
import json
import sys

(
    output,
    asset_name,
    dmg_sha,
    installer_sha,
    companion_sha,
    source_commit,
    payload_ref,
    payload_commit,
    signature,
    sdk_version,
) = sys.argv[1:]
data = {
    "schemaVersion": 2,
    "version": "0.2.3",
    "platform": "macos",
    "architecture": "arm64",
    "installerSourceCommit": source_commit,
    "payloadRef": payload_ref,
    "payloadCommit": payload_commit,
    "asset": {"name": asset_name, "sha256": dmg_sha},
    "installer": {"executableSha256": installer_sha, "signature": signature},
    "companion": {"executableSha256": companion_sha},
    "sdk": {"name": "macosx", "version": sdk_version},
    "notarized": False,
}
with open(output, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY

printf 'Created %s\nCreated %s\nCreated %s\n' "$dmg" "$checksums" "$provenance"
