#!/usr/bin/env bash
set -euo pipefail

plugin_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$plugin_root/scripts/select-signing-identity.sh"
package_root="$plugin_root/native"
assets_root="$plugin_root/assets"
output_app="$assets_root/Codex Usage Sidebar.app"
manifest="$plugin_root/.codex-plugin/plugin.json"
version="$(/usr/bin/python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$manifest")"
bundle_version="${version%%+*}"

if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

/bin/mkdir -p "$plugin_root/.build" "$assets_root"
staging_root="$(mktemp -d "$plugin_root/.build/companion.XXXXXX")"
staged_app="$staging_root/Codex Usage Sidebar.app"

cleanup() {
  if [[ "$staging_root" == "$plugin_root/.build/companion."* ]]; then
    /bin/rm -rf "$staging_root"
  fi
}
trap cleanup EXIT

xcrun swift test --package-path "$package_root"
xcrun swift build \
  -c release \
  --arch arm64 \
  --package-path "$package_root"
release_bin_path="$(
  xcrun swift build \
    -c release \
    --arch arm64 \
    --show-bin-path \
    --package-path "$package_root"
)"
release_binary="$release_bin_path/CodexUsageSidebar"
[[ -x "$release_binary" ]] || {
  printf 'release executable is missing: %s\n' "$release_binary" >&2
  exit 66
}

/bin/mkdir -p \
  "$staged_app/Contents/MacOS" \
  "$staged_app/Contents/Resources"
/usr/bin/install -m 0755 \
  "$release_binary" \
  "$staged_app/Contents/MacOS/CodexUsageSidebar"
/usr/bin/install -m 0644 \
  "$plugin_root/assets/quota-icon-dark.png" \
  "$staged_app/Contents/Resources/quota-icon-dark.png"
/usr/bin/install -m 0644 \
  "$plugin_root/assets/quota-icon-light.png" \
  "$staged_app/Contents/Resources/quota-icon-light.png"

/bin/cat >"$staged_app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>Codex Usage Sidebar</string>
  <key>CFBundleExecutable</key>
  <string>CodexUsageSidebar</string>
  <key>CFBundleIdentifier</key>
  <string>com.jace.codex-usage-sidebar</string>
  <key>CFBundleName</key>
  <string>Codex Usage Sidebar</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$bundle_version</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSAccessibilityUsageDescription</key>
  <string>Used only to position Codex quota information beside the app's native controls.</string>
</dict>
</plist>
PLIST

/usr/bin/plutil -lint "$staged_app/Contents/Info.plist" >/dev/null
signing_identity="$(select_signing_identity)"
signing_arguments=(
  --force
  --deep
  --sign "$signing_identity"
)
if [[ "$signing_identity" == "-" ]]; then
  signing_arguments+=(
    --requirements
    '=designated => identifier "com.jace.codex-usage-sidebar"'
  )
fi
/usr/bin/codesign "${signing_arguments[@]}" "$staged_app"
/usr/bin/codesign --verify --deep --strict "$staged_app"

if [[ "$output_app" != "$assets_root/Codex Usage Sidebar.app" ]]; then
  printf 'refusing unsafe output path: %s\n' "$output_app" >&2
  exit 70
fi
/bin/rm -rf "$output_app"
/usr/bin/ditto "$staged_app" "$output_app"
/usr/bin/codesign --verify --deep --strict "$output_app"

printf 'Built and signed: %s\n' "$output_app"
