# Codex Usage Sidebar v0.3.2 progress

## Release baseline

`v0.3.2` is published on [GitHub Releases](https://github.com/JaceHwang/codex-usage-sidebar/releases/tag/v0.3.2) for:

| Platform | Asset | Scope |
| --- | --- | --- |
| macOS 14+ Apple Silicon | `codex-usage-sidebar-v0.3.2-macos-arm64.dmg` | Signed companion, graphical installer, SHA-256 and provenance assets |
| Windows 11 AMD64/x64 | `codex-usage-sidebar-v0.3.2-windows-x64-setup.exe` | Current-user unsigned setup, SHA-256 and provenance assets |

Windows ARM64 is unsupported. The Windows setup must be verified before launch and may show an expected unsigned-publisher prompt; no user should disable Windows security controls.

## Included functionality

- titlebar remaining-quota control with collision-aware nearby placement and safe fallback;
- live local app-server rate-limit updates, reset countdown, Credits, Bank entries and expiry/status;
- seven-day Token usage plus cycle total from `account/usage/read`;
- account identity from `account/read`, with safe localized fallbacks;
- Simplified Chinese, Traditional Chinese, English, and English fallback for other locales;
- light/dark plugin icon, shared red/orange/green quota palette, hover and click-to-pin card, GitHub footer link;
- the current v0.3.2 card intentionally does not render a Tibo X row;
- no official Codex-bundle modification, browser scraping, credential copying, or telemetry.

## Verification recorded

- macOS native Swift suite: 272 tests passed for the v0.3.2 release source.
- macOS installer package, embedded payload, arm64 identity, DMG verification, plugin validation, and public-repository validation passed.
- Windows portable Core tests, source build, payload/provenance checks, and workflow checks passed.
- GitHub main CI run [32588648846](https://github.com/JaceHwang/codex-usage-sidebar/actions/runs/32588648846) passed after companion provenance synchronization.

## Remaining Windows device gate

The release does not claim full Windows real-device coverage. A Windows 11 AMD64/x64 device must still capture the pane/window, theme, language, DPI, hover/pin, lifecycle, install/repair/uninstall, and unsupported-UIA matrix described in [WINDOWS-DEVICE-HANDOFF.md](WINDOWS-DEVICE-HANDOFF.md). Unknown UI Automation structures must stay fail-hidden.

## Maintenance rules

1. Keep Git commits and verified Release assets as the source of truth across macOS and Windows.
2. Do not move the `v0.3.2` tag or overwrite existing release assets.
3. Rebuild the companion and update `assets/PROVENANCE.json` together; CI checks that the executable SHA-256 matches the recorded provenance.
4. Preserve local user changes and generated artifacts unless they are explicitly part of a verified release operation.
