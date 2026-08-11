#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dist="$repo_root/.dist"
app="$dist/installer/Codex Usage Sidebar Installer.app"
dmg="$dist/codex-usage-sidebar-v0.2.3-macos-arm64.dmg"
checksums="$dist/INSTALLER-SHA256SUMS.txt"
provenance="$dist/INSTALLER-PROVENANCE.json"
verifier="$repo_root/scripts/verify-installer-package.sh"
finalizer="$repo_root/scripts/finalize-installer-provenance.py"

[[ -x "$repo_root/scripts/build-installer.sh" ]]
[[ -x "$repo_root/scripts/package-installer.sh" ]]
[[ -x "$verifier" ]]
[[ -x "$finalizer" ]]

DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}" \
  "$repo_root/scripts/build-installer.sh"
"$repo_root/scripts/package-installer.sh"

[[ -d "$app" ]]
[[ -f "$dmg" ]]
[[ -f "$checksums" ]]
[[ -f "$provenance" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")" == "0.2.3" ]]
[[ "$(/usr/bin/python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"].split("+")[0])' "$app/Contents/Resources/payload/plugins/codex-usage-sidebar/.codex-plugin/plugin.json")" == "0.2.3" ]]

/usr/bin/codesign --verify --deep --strict "$app"
[[ "$(/usr/bin/lipo -archs "$app/Contents/MacOS/CodexUsageSidebarInstaller")" == "arm64" ]]
/usr/bin/hdiutil verify "$dmg" >/dev/null
("$verifier" "$app" "$dmg")
(cd "$dist" && /usr/bin/shasum -a 256 -c "$(basename "$checksums")")

mount_root="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/cus-installer-mount.XXXXXX")"
payload_compare_root=""
cleanup() {
  /usr/sbin/diskutil eject "$mount_root" >/dev/null 2>&1 || true
  /bin/rmdir "$mount_root" >/dev/null 2>&1 || true
  if [[ -n "$payload_compare_root" ]]; then
    /bin/rm -rf "$payload_compare_root"
  fi
}
trap cleanup EXIT
/usr/sbin/diskutil image attach \
  --nobrowse \
  --readOnly \
  --mountPoint "$mount_root" \
  "$dmg" >/dev/null
mounted_app="$mount_root/Codex Usage Sidebar Installer.app"
[[ -d "$mounted_app" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$mounted_app/Contents/Info.plist")" == "0.2.3" ]]

expected_payload_commit="$(/usr/bin/git -C "$repo_root" rev-parse 'HEAD^{commit}')"
/usr/bin/python3 - "$provenance" "$expected_payload_commit" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1]))
assert data["payloadCommit"] == sys.argv[2]
PY

payload_compare_root="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/cus-installer-payload.XXXXXX")"
expected_payload_root="$payload_compare_root/expected"
/bin/mkdir "$expected_payload_root"
/usr/bin/git -C "$repo_root" archive "$expected_payload_commit" \
  .agents/plugins/marketplace.json \
  plugins/codex-usage-sidebar |
  /usr/bin/tar -xf - -C "$expected_payload_root"
/usr/bin/diff -qr "$expected_payload_root" "$mounted_app/Contents/Resources/payload"

if /usr/bin/find "$mounted_app/Contents/Resources/payload" \
  \( -name .git -o -name .build -o -name .dist -o -name .DS_Store -o -name __MACOSX \) \
  -print -quit | /usr/bin/grep -q .; then
  echo "installer payload contains repository or generated metadata" >&2
  exit 1
fi

/usr/bin/python3 - "$provenance" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1]))
assert data["schemaVersion"] == 2
assert data["version"] == "0.2.3"
assert data["asset"]["name"] == "codex-usage-sidebar-v0.2.3-macos-arm64.dmg"
assert data["platform"] == "macos"
assert data["architecture"] == "arm64"
assert data["sdk"]["name"] == "macosx"
assert data["sdk"]["version"]
assert data["notarized"] is False
PY

negative_root="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/cus-installer-negative.XXXXXX")"
cleanup_negative() {
  /bin/rm -rf "$negative_root"
}
trap 'cleanup; cleanup_negative' EXIT

expect_rejected() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    printf 'negative package case was accepted: %s\n' "$label" >&2
    exit 1
  fi
}

expect_rejected invalid-payload-ref \
  /usr/bin/env CUS_INSTALLER_PAYLOAD_REF=missing-installer-payload-ref \
  "$repo_root/scripts/build-installer.sh"

wrong_version_app="$negative_root/Wrong Version.app"
/usr/bin/ditto "$app" "$wrong_version_app"
/usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString 0.2.4' \
  "$wrong_version_app/Contents/Info.plist"
/usr/bin/codesign --force --deep --sign - "$wrong_version_app" >/dev/null
expect_rejected wrong-version "$verifier" "$wrong_version_app" "$dmg"

wrong_name="$negative_root/codex-usage-sidebar-v0.2.3-macos.dmg"
/bin/cp "$dmg" "$wrong_name"
expect_rejected wrong-name "$verifier" "$app" "$wrong_name"

missing_payload_app="$negative_root/Missing Payload.app"
/usr/bin/ditto "$app" "$missing_payload_app"
/bin/rm -f \
  "$missing_payload_app/Contents/Resources/payload/plugins/codex-usage-sidebar/.codex-plugin/plugin.json"
/usr/bin/codesign --force --deep --sign - "$missing_payload_app" >/dev/null
expect_rejected missing-payload "$verifier" "$missing_payload_app" "$dmg"

invalid_signature_app="$negative_root/Invalid Signature.app"
/usr/bin/ditto "$app" "$invalid_signature_app"
/usr/bin/printf '\ninvalid-signature\n' >>"$invalid_signature_app/Contents/Info.plist"
expect_rejected invalid-signature "$verifier" "$invalid_signature_app" "$dmg"

wrong_arch_app="$negative_root/Wrong Architecture.app"
/usr/bin/ditto "$app" "$wrong_arch_app"
/usr/bin/lipo -thin x86_64 /usr/bin/true \
  -output "$wrong_arch_app/Contents/MacOS/CodexUsageSidebarInstaller"
/usr/bin/codesign --force --deep --sign - "$wrong_arch_app" >/dev/null
expect_rejected non-arm64 "$verifier" "$wrong_arch_app" "$dmg"

malformed_dir="$negative_root/malformed"
malformed_source="$negative_root/malformed-source"
malformed_dmg="$malformed_dir/codex-usage-sidebar-v0.2.3-macos-arm64.dmg"
/bin/mkdir -p "$malformed_dir" "$malformed_source"
/usr/bin/printf 'not an installer\n' >"$malformed_source/README.txt"
/usr/sbin/diskutil image create from \
  --volumeName "Malformed Installer" \
  --format UDZO \
  "$malformed_source" \
  "$malformed_dmg" >/dev/null
expect_rejected malformed-dmg "$verifier" "$app" "$malformed_dmg"

source_commit="$(/usr/bin/python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["installerSourceCommit"])' "$provenance")"
sdk_version="$(/usr/bin/python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["sdk"]["version"])' "$provenance")"
promoted="$negative_root/INSTALLER-PROVENANCE.promoted.json"
finalize_fixture() {
  local output="$1"
  local run_repository="$2"
  local head_sha="$3"
  local branch="$4"
  local artifact_digest="$5"
  local release_tag="$6"
  local fixture_sdk="$7"
  "$finalizer" \
  --input "$provenance" \
  --output "$output" \
  --expected-repository JaceHwang/codex-usage-sidebar \
  --run-repository "$run_repository" \
  --run-id 123456 \
  --run-url https://github.com/JaceHwang/codex-usage-sidebar/actions/runs/123456 \
  --head-sha "$head_sha" \
  --workflow-path .github/workflows/ci.yml \
  --event push \
  --branch "$branch" \
  --artifact-id 987654 \
  --artifact-name codex-usage-sidebar-installer-v0.2.3 \
  --artifact-digest "$artifact_digest" \
  --release-tag "$release_tag" \
  --sdk-version "$fixture_sdk"
}

valid_artifact_digest=sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
finalize_fixture \
  "$promoted" \
  JaceHwang/codex-usage-sidebar \
  "$source_commit" \
  main \
  "$valid_artifact_digest" \
  v0.2.3 \
  "$sdk_version"

/usr/bin/python3 - "$promoted" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1]))
assert data["ci"]["repository"] == "JaceHwang/codex-usage-sidebar"
assert data["ci"]["event"] == "push"
assert data["ci"]["branch"] == "main"
assert data["artifact"]["id"] == 987654
assert data["artifact"]["name"] == "codex-usage-sidebar-installer-v0.2.3"
assert data["artifact"]["digest"].startswith("sha256:")
assert data["release"]["tag"] == "v0.2.3"
assert data["sdk"]["version"]
PY

expect_rejected external-repository finalize_fixture \
  "$promoted" attacker/fork "$source_commit" main "$valid_artifact_digest" v0.2.3 "$sdk_version"
expect_rejected non-main-run finalize_fixture \
  "$promoted" JaceHwang/codex-usage-sidebar "$source_commit" feature \
  "$valid_artifact_digest" v0.2.3 "$sdk_version"
expect_rejected wrong-source-commit finalize_fixture \
  "$promoted" JaceHwang/codex-usage-sidebar \
  aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa main "$valid_artifact_digest" v0.2.3 "$sdk_version"
expect_rejected malformed-artifact-digest finalize_fixture \
  "$promoted" JaceHwang/codex-usage-sidebar "$source_commit" main sha256:not-a-digest \
  v0.2.3 "$sdk_version"
expect_rejected wrong-release finalize_fixture \
  "$promoted" JaceHwang/codex-usage-sidebar "$source_commit" main \
  "$valid_artifact_digest" v0.2.4 "$sdk_version"
expect_rejected wrong-sdk finalize_fixture \
  "$promoted" JaceHwang/codex-usage-sidebar "$source_commit" main \
  "$valid_artifact_digest" v0.2.3 0.0

printf 'PASS: v0.2.3 macOS arm64 installer app and DMG are valid\n'
