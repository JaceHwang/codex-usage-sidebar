#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="0.3.3"
required_branch="v0.3.2"
output_root="$repo_root/.dist/v0.3.3/macos"
app="$output_root/Codex Usage Sidebar Installer.app"
asset_name="codex-usage-sidebar-v0.3.3-macos-arm64.dmg"
dmg="$output_root/$asset_name"
checksums="$output_root/MACOS-V033-SHA256SUMS.txt"
provenance="$output_root/MACOS-V033-PROVENANCE.json"
stage_root=""

cleanup() {
  if [[ -n "$stage_root" && "$stage_root" == "${TMPDIR:-/tmp}"/cus-macos-v033-package.* ]]; then
    /bin/rm -rf "$stage_root"
  fi
}
trap cleanup EXIT

[[ "$(/usr/bin/git -C "$repo_root" branch --show-current)" == "$required_branch" ]] || {
  printf 'macOS v0.3.3 package requires branch %s\n' "$required_branch" >&2
  exit 65
}
for target in "$dmg" "$checksums" "$provenance"; do
  [[ ! -e "$target" ]] || { printf 'refusing to overwrite macOS release asset: %s\n' "$target" >&2; exit 66; }
done
[[ -d "$app" ]] || { printf 'macOS v0.3.3 installer app is missing\n' >&2; exit 66; }
/usr/bin/codesign --verify --deep --strict "$app"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")" == "$version" ]]
[[ "$(/usr/bin/lipo -archs "$app/Contents/MacOS/CodexUsageSidebarInstaller")" == "arm64" ]]

source_commit="$(/usr/bin/git -C "$repo_root" rev-parse 'HEAD^{commit}')"
payload_commit="$(/bin/cat "$app/Contents/Resources/InstallerPayloadCommit")"
[[ "$payload_commit" == "$source_commit" ]] || {
  printf 'macOS v0.3.3 installer payload commit differs from current source\n' >&2
  exit 67
}

stage_root="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/cus-macos-v033-package.XXXXXX")"
image_source="$stage_root/image-source"
/bin/mkdir "$image_source"
/usr/bin/ditto "$app" "$image_source/Codex Usage Sidebar Installer.app"
/bin/cat >"$image_source/首次打开说明.txt" <<'TEXT'
Codex Usage Sidebar v0.3.3

1. 双击“Codex Usage Sidebar Installer”。
2. 如果 macOS 阻止打开，请在 Finder 中右键安装器并选择“打开”。
3. 点击“安装”，按引导完成 Codex 登录和辅助功能授权。

English:
1. Open “Codex Usage Sidebar Installer”.
2. If macOS blocks this raw asset, right-click the installer in Finder and choose Open.
3. Click Install, then finish Codex login and Accessibility authorization.
TEXT

temporary_dmg="$stage_root/$asset_name"
/usr/bin/hdiutil create -volname "Codex Usage Sidebar v$version" -srcfolder "$image_source" \
  -ov -format UDZO "$temporary_dmg" >/dev/null
/usr/bin/hdiutil verify "$temporary_dmg" >/dev/null
"$repo_root/scripts/verify-macos-v033-installer-package.sh" "$app" "$temporary_dmg"
/bin/mv "$temporary_dmg" "$dmg"

dmg_sha="$(/usr/bin/shasum -a 256 "$dmg" | /usr/bin/awk '{print $1}')"
installer_sha="$(/usr/bin/shasum -a 256 "$app/Contents/MacOS/CodexUsageSidebarInstaller" | /usr/bin/awk '{print $1}')"
companion="$app/Contents/Resources/payload/plugins/codex-usage-sidebar/assets/Codex Usage Sidebar.app/Contents/MacOS/CodexUsageSidebar"
companion_sha="$(/usr/bin/shasum -a 256 "$companion" | /usr/bin/awk '{print $1}')"
sdk_version="$(DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}" /usr/bin/xcrun --sdk macosx --show-sdk-version)"
signature="adhoc"
team_identifier="$(/usr/bin/codesign -dv --verbose=4 "$app" 2>&1 | /usr/bin/awk -F= '/^TeamIdentifier=/{print $2}')"
if [[ -n "$team_identifier" && "$team_identifier" != "not set" ]]; then
  signature="developer-id"
fi

/usr/bin/python3 - "$provenance" "$asset_name" "$dmg_sha" "$installer_sha" \
  "$companion_sha" "$source_commit" "$signature" "$sdk_version" <<'PY'
import json
import sys

output, asset, dmg_sha, installer_sha, companion_sha, source, signature, sdk = sys.argv[1:]
with open(output, "x", encoding="utf-8") as handle:
    json.dump({
        "schemaVersion": 1,
        "status": "local-release-asset",
        "version": "0.3.3",
        "platform": "macos",
        "architecture": "arm64",
        "sourceCommit": source,
        "payloadCommit": source,
        "asset": {"name": asset, "sha256": dmg_sha},
        "installer": {"executableSha256": installer_sha, "signature": signature},
        "companion": {"executableSha256": companion_sha},
        "sdk": {"name": "macosx", "version": sdk},
        "notarized": False,
    }, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY
/usr/bin/printf '%s  %s\n' "$dmg_sha" "$asset_name" >"$checksums"
printf 'Created %s\nCreated %s\nCreated %s\n' "$dmg" "$checksums" "$provenance"
