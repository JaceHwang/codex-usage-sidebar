#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
plugin_manifest="$repo_root/plugins/codex-usage-sidebar/.codex-plugin/plugin.json"
native_root="$repo_root/plugins/codex-usage-sidebar/native"
dist="$repo_root/.dist"
output_root="$dist/installer"
app="$output_root/Codex Usage Sidebar Installer.app"
payload_ref="${CUS_INSTALLER_PAYLOAD_REF:-v0.2.3}"
signing_identity="${CUS_INSTALLER_SIGN_IDENTITY:--}"
version="$(/usr/bin/python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"].split("+")[0])' "$plugin_manifest")"

if [[ "$version" != "0.2.3" ]]; then
  printf 'installer packaging requires plugin version 0.2.3, found %s\n' "$version" >&2
  exit 65
fi
/usr/bin/git -C "$repo_root" cat-file -e "$payload_ref^{commit}"

/bin/mkdir -p "$dist"
/bin/rm -rf "$output_root"
/bin/mkdir -p \
  "$app/Contents/MacOS" \
  "$app/Contents/Resources/payload"

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
/bin/cp "$bin_path/CodexUsageSidebarInstaller" \
  "$app/Contents/MacOS/CodexUsageSidebarInstaller"
/bin/chmod 755 "$app/Contents/MacOS/CodexUsageSidebarInstaller"

/usr/bin/git -C "$repo_root" archive \
  "$payload_ref" \
  .agents/plugins/marketplace.json \
  plugins/codex-usage-sidebar |
  /usr/bin/tar -xf - -C "$app/Contents/Resources/payload"

/bin/cat >"$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>Codex Usage Sidebar Installer</string>
  <key>CFBundleExecutable</key>
  <string>CodexUsageSidebarInstaller</string>
  <key>CFBundleIdentifier</key>
  <string>com.jace.codex-usage-sidebar.installer</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Codex Usage Sidebar Installer</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$version</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.utilities</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

/usr/bin/plutil -lint "$app/Contents/Info.plist" >/dev/null
if [[ "$signing_identity" == "-" ]]; then
  /usr/bin/codesign --force --sign - "$app"
else
  /usr/bin/codesign \
    --force \
    --options runtime \
    --timestamp \
    --sign "$signing_identity" \
    "$app"
fi
/usr/bin/codesign --verify --deep --strict "$app"
[[ "$(/usr/bin/lipo -archs "$app/Contents/MacOS/CodexUsageSidebarInstaller")" == "arm64" ]]

printf 'Built %s\n' "$app"
