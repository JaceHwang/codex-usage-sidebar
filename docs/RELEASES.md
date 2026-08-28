# Release Operations

This project supports independent platform maintenance releases and unified cross-platform feature
releases. The release catalog is the source of truth for platform version, tag, title, architecture,
support boundary, asset names, and release notes.

## Before creating a release

1. Classify the change using [`VERSIONING.md`](../VERSIONING.md), update `CHANGELOG.md`, and update
   the release catalog. A planned candidate must use `macos-vX.Y.Z` or `windows-vX.Y.Z`; shared
   parity releases use `vX.Y.Z`.
2. Update the platform application/installer version and confirm it equals the catalog version.
   Cachebuster values are build metadata, never product versions.
3. Run `python3 scripts/validate-platform-release.py --catalog releases/platform-release-catalog.json
   --target <platform>`, the platform test suite, and the release-pipeline regression test.

## Build and publish

1. Build from the same verified commit that will receive the tag. The macOS generic scripts accept
   the catalog and target and embed that commit in the installer payload.
2. Generate the platform installer, checksum file, and provenance. Use the catalog-defined asset
   names; do not overwrite an existing release artifact.
3. Create the GitHub Release with the catalog title, exact tag, target system/Codex compatibility,
   upgrade notes, known limitations, and the other platform's current status. Upload the installer,
   `SHA256SUMS.txt`, and `PROVENANCE` together.
4. Verify the published files against their checksums and complete clean-install, upgrade,
   first-open, data-refresh, and uninstall/reinstall checks on the target device.

GitHub Release assets must be generated from the same verified commit. If an asset is wrong, publish
a new PATCH release rather than replacing the existing release content.

## Platform matrix in user documentation

The README platform matrix always lists each platform's latest **published** release, not the newest
candidate. A platform-only release states that the other platform is unchanged and links to its own
latest release. A unified release provides both installers with the same version.
