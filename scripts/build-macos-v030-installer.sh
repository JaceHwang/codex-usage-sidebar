#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="0.3.0"
required_branch="v0.3.0"
signing_identity="${CUS_INSTALLER_SIGN_IDENTITY:--}"
output_root="$repo_root/.dist/v0.3.0/macos"
final_app="$output_root/Codex Usage Sidebar Installer.app"
stage_root=""

cleanup() {
  if [[ -n "$stage_root" && "$stage_root" == "${TMPDIR:-/tmp}"/cus-macos-v030-build.* ]]; then
    /bin/rm -rf "$stage_root"
  fi
}
trap cleanup EXIT

branch="$(/usr/bin/git -C "$repo_root" branch --show-current)"
[[ "$branch" == "$required_branch" ]] || {
  printf 'macOS v0.3.0 candidate requires exact branch %s, found %s\n' "$required_branch" "$branch" >&2
  exit 65
}
[[ -z "$(/usr/bin/git -C "$repo_root" status --porcelain=v1 --untracked-files=all)" ]] || {
  printf 'macOS v0.3.0 candidate requires a clean tracked and untracked worktree\n' >&2
  exit 65
}
source_commit="$(/usr/bin/git -C "$repo_root" rev-parse 'HEAD^{commit}')"
packaging_commit="$source_commit"
source_commit="${CUS_V030_SOURCE_COMMIT:-}"
[[ "$source_commit" =~ ^[0-9a-f]{40}$ ]] || {
  printf 'macOS v0.3.0 candidate requires CUS_V030_SOURCE_COMMIT from validated evidence\n' >&2
  exit 65
}
/usr/bin/python3 "$repo_root/scripts/verify-v030-packaging-delta.py" \
  --repository "$repo_root" \
  --validated-source-commit "$source_commit" \
  --packaging-commit "$packaging_commit" \
  --allowed-path docs/validation/windows-v0.3.0.json
[[ ! -e "$final_app" ]] || {
  printf 'refusing to overwrite macOS v0.3.0 candidate app: %s\n' "$final_app" >&2
  exit 66
}

stage_root="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/cus-macos-v030-build.XXXXXX")"
source_root="$stage_root/source"
app="$stage_root/Codex Usage Sidebar Installer.app"
/bin/mkdir -p "$source_root" "$app/Contents/MacOS" "$app/Contents/Resources/payload"
/usr/bin/git -C "$repo_root" archive "$source_commit" | /usr/bin/tar -xf - -C "$source_root"

plugin_manifest="$source_root/plugins/codex-usage-sidebar/.codex-plugin/plugin.json"
native_root="$source_root/plugins/codex-usage-sidebar/native"
plugin_version="$(/usr/bin/python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"].split("+",1)[0])' "$plugin_manifest")"
[[ "$plugin_version" == "$version" ]] || {
  printf 'macOS v0.3.0 candidate requires embedded plugin version %s, found %s\n' "$version" "$plugin_version" >&2
  exit 65
}

DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}" \
  /usr/bin/xcrun swift build \
    --package-path "$native_root" \
    --configuration release \
    --arch arm64 \
    --product CodexUsageSidebarInstaller
bin_path="$(
  DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}" \
    /usr/bin/xcrun swift build \
      --package-path "$native_root" \
      --configuration release \
      --arch arm64 \
      --show-bin-path
)"
/bin/cp "$bin_path/CodexUsageSidebarInstaller" "$app/Contents/MacOS/CodexUsageSidebarInstaller"
/bin/chmod 755 "$app/Contents/MacOS/CodexUsageSidebarInstaller"

/usr/bin/git -C "$repo_root" archive \
  "$source_commit" \
  .agents/plugins/marketplace.json \
  plugins/codex-usage-sidebar | /usr/bin/tar -xf - -C "$app/Contents/Resources/payload"
/usr/bin/printf '%s\n' "$source_commit" >"$app/Contents/Resources/InstallerPayloadCommit"

/bin/cat >"$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleDisplayName</key><string>Codex Usage Sidebar Installer</string>
  <key>CFBundleExecutable</key><string>CodexUsageSidebarInstaller</string>
  <key>CFBundleIdentifier</key><string>com.jace.codex-usage-sidebar.installer</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>Codex Usage Sidebar Installer</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$version</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

/usr/bin/plutil -lint "$app/Contents/Info.plist" >/dev/null
if [[ "$signing_identity" == "-" ]]; then
  /usr/bin/codesign --force --sign - "$app"
else
  /usr/bin/codesign --force --options runtime --timestamp --sign "$signing_identity" "$app"
fi
/usr/bin/codesign --verify --deep --strict "$app"
[[ "$(/usr/bin/lipo -archs "$app/Contents/MacOS/CodexUsageSidebarInstaller")" == "arm64" ]]

/bin/mkdir -p "$output_root"
/bin/mv "$app" "$final_app"
printf 'Built %s from validated %s at packaging %s\n' "$final_app" "$source_commit" "$packaging_commit"
