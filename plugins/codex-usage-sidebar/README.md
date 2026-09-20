# Plugin payload

This is the installable plugin directory. Development source retains product version **0.4.0**;
see the [repository README](../../README.md) / [中文说明](../../README.zh-CN.md) for download versions,
current native renders, installation and support.

The macOS companion displays primary/secondary quota windows, seven-day Tokens, account identity,
Credits and Bank expiry/status. It provides hover/click pin, an independent detail lock, resizable
scrolling details, a GitHub footer and settings (position mode, Releases link, reload, quit).
Automatic placement searches safe space; occupied default fallback switches persistently to Free.
Free allows dragging and Locked fixes the manual position. These modes are separate from detail lock.
The light detail surface is opaque pure white and detail height has no product maximum beyond screen
space. Windows development source follows those rules and exposes position choices by indicator
right-click as well as through settings, while retaining its UIA/Safe Dock safety policy.

Read [current features](../../docs/CURRENT_FEATURES.md), [current design](../../docs/CURRENT_DESIGN.md)
and [privacy](../../docs/PRIVACY.md). Windows source and macOS-local tests do not establish a newly
published Windows build. The release catalog retains the published-platform matrix.

```bash
bash scripts/build-companion.sh
bash tests/test-sidebar-control.sh
bash tests/test-signing-identity.sh
bash tests/test-bundle-version.sh
bash tests/test-build-sdk.sh
bash tests/live-app-server-probe.sh # requires isolated CodexHome login
```

A local build does not publish a release. Follow the repository governance entrypoint before
committing, pushing or releasing. Snapshot/dirty metadata must not be presented as exact CI provenance.
