# Plugin payload

This directory is the installable `codex-usage-sidebar` plugin referenced by the repository's Git
marketplace manifest. Start at the [repository README](../../README.md) for installation,
screenshots, privacy, support, and contribution instructions.

Its native companion shows one live quota control in the central content header. The control tracks
the Open Location action directly with a fixed 8-point gap as sidebars and the window change; it
never creates a second control in the left sidebar.

Developer verification:

```bash
bash scripts/build-companion.sh
bash tests/test-sidebar-control.sh
bash tests/live-app-server-probe.sh
```
