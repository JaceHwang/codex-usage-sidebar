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

## Published and independently verified

- Feature PR [#11](https://github.com/JaceHwang/codex-usage-sidebar/pull/11) and generated Release Please PR [#12](https://github.com/JaceHwang/codex-usage-sidebar/pull/12) merged after all checks passed.
- Release tag `v0.4.0`: `75836c5dd9db142ff0725a7ea9335e53b42c9d52`.
- [Publication workflow](https://github.com/JaceHwang/codex-usage-sidebar/actions/runs/35111553297) succeeded.
- [Public release](https://github.com/JaceHwang/codex-usage-sidebar/releases/tag/v0.4.0) contains the arm64 DMG, SHA-256 file and provenance JSON.
- Downloaded all three public assets again; checksum, mounted installer and companion signatures, both binary SDKs, embedded source commit and executable digests passed `.governance/project/verify-release macos-arm64 v0.4.0`.
- DMG SHA-256: `a5dd1e6cce7ebd7e413457077a47bb5cbe096b8aff4a968cab2a13c022ae86af`.
- Installer is ad-hoc signed and not notarized, as recorded in published provenance and installation guidance.
- Windows remains on its separately published v0.3.3 installer.
