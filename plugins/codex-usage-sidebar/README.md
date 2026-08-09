# Plugin payload

This directory is the installable `codex-usage-sidebar` plugin referenced by the repository's Git
marketplace manifest. Start at the [repository README](../../README.md) for installation,
screenshots, privacy, support, and contribution instructions.

Its native companion shows one live quota control exactly 8 points before Open Location. It tracks
the Open Location action directly with a fixed 8-point gap as sidebars and the window change; it
never creates a second control in the left sidebar.

The hover card shows the synchronized bundle version beside its title. Percentage text uses exact
100% green, 49% orange, and 10% red anchors, while the filled progress bar clips the matching
red-to-orange-to-green spectrum. Managed status reports the actual LaunchAgent PID, version, anchor,
and indicator frame.

Developer verification:

```bash
bash scripts/build-companion.sh
bash tests/test-sidebar-control.sh
bash tests/test-signing-identity.sh
bash tests/test-bundle-version.sh
bash tests/test-build-sdk.sh
bash tests/live-app-server-probe.sh
```
