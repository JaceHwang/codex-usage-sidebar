# Plugin payload

This directory is the installable `codex-usage-sidebar` plugin referenced by the repository's Git
marketplace manifest. Start at the [repository README](../../README.md) for installation,
screenshots, privacy, support, and contribution instructions.

On Codex main surfaces, its native companion keeps the live quota control in the right titlebar
whether the sidebar is expanded or collapsed. Settings and other completed non-main surfaces hide
the control.

Developer verification:

```bash
bash scripts/build-companion.sh
bash tests/test-sidebar-control.sh
bash tests/live-app-server-probe.sh
```
