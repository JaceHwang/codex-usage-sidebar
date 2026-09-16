# macOS 0.4.0 release preparation

## Completed locally

- Reconciled catalog and staged publisher to governed `v0.4.0`; no manual tag created.
- Added versioned build/package/verifier scripts, derived from the v0.3.5 chain without changing historical scripts.
- Added exact-tag/source/payload/SDK/asset-digest verification and five positive/negative provenance tests.
- Added real installed companion screenshot to both READMEs: `docs/images/current/live-macos-indicator.jpg`, captured 2026-09-16. Fixed-data PNG galleries remain separately labelled.
- Ordinary feature changes retain released product version 0.3.5 until Release Please performs the version bump. The separately installed local candidate remains 0.4.0.
- `./governance doctor`: passed, including five provenance tests.
- Shell syntax and unsupported version/platform rejection: passed.
- 252 local documentation references: no missing targets.
- `git diff --check`: passed.

## Toolchain recovery and verification

Xcode 27 setup is now complete. Explicit native SwiftPM builds with the retained macOS 26.5 SDK
pass **334 Swift tests**. The rebuilt arm64 companion reports SDK 26.5 and passes strict signing.
`./governance check all` passes, including installation lifecycle, bundle version, signing identity
and **8 provenance tests**. Independent review confirmed mounted DMG payloads are bound to the
release source and executable hashes, and both shipped binaries are checked for SDK 26.5.

Commands used:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk \
bash plugins/codex-usage-sidebar/scripts/build-companion.sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk \
./governance check all
```

## Remaining release steps

1. Pass full governance verification; commit integrated source without an ordinary version bump.
2. Rebuild the tracked companion from the source commit, sign it and record its exact provenance; commit the payload and rerun all checks before push.
3. Merge the feature PR after required CI. Review the generated Release Please 0.4.0 PR, rebuild its changed bundle metadata/signature, pass required checks and merge.
4. Publish macOS using `publish-platform.yml` from the generated `v0.4.0` tag. Download and independently verify the three immutable release assets.
5. Update the published catalog and download links only after successful publication; Windows remains at v0.3.3.

No 0.4.0 release or new tag was published during this preparation.
