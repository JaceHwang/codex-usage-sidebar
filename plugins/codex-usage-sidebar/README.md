# Plugin payload

This directory is the installable `codex-usage-sidebar` plugin referenced by the repository's Git
marketplace manifest. Start at the [repository README](../../README.md) for installation,
screenshots, privacy, support, and contribution instructions.

Its native companion shows one live quota control in a collision-free Codex titlebar slot. Version
0.3.0 prefers an exact 8-point Open Location gap, slides left to the nearest complete free slot when
native controls occupy that frame, and uses the safe right-side fallback when no local slot remains.
Fullscreen content clipped to a 1-point top-edge frame is ignored rather than treated as a titlebar
obstacle. The companion never creates a second control in the left sidebar.

The hover card shows the synchronized bundle version beside its title, the current-cycle daily and
total token usage chart, and Codex account identity in the footer. Its compact footer contains a
borderless GitHub button that opens the project repository at
`https://github.com/JaceHwang/codex-usage-sidebar`; the resting state blends into the background,
while hover adds a soft rounded shadow. Percentage text uses exact
100% green, 49% orange, and 10% red anchors, while the filled progress bar clips the matching
red-to-orange-to-green spectrum. Managed status reports the actual LaunchAgent PID, version, anchor,
indicator frame, mapped language, and language source.

Version 0.2.0 follows Codex's effective Simplified Chinese, Traditional Chinese, or English locale,
including the final locale resolved by Codex when its setting is Auto; unsupported locales use
English. Click pins the quota card until the next click, while hover remains available.

Developer verification:

```bash
bash scripts/build-companion.sh
bash tests/test-sidebar-control.sh
bash tests/test-signing-identity.sh
bash tests/test-bundle-version.sh
bash tests/test-build-sdk.sh
bash tests/live-app-server-probe.sh
```
