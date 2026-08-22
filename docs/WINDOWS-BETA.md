# Windows v0.3.2 release and device gate

## Release status

`v0.3.2` publishes an unsigned, current-user Windows 11 AMD64/x64 setup:

- `codex-usage-sidebar-v0.3.2-windows-x64-setup.exe`
- `WINDOWS-V032-SHA256SUMS.txt`
- `WINDOWS-V032-PROVENANCE.json`

Download all three only from the [v0.3.2 GitHub Release](https://github.com/JaceHwang/codex-usage-sidebar/releases/tag/v0.3.2), verify the setup SHA-256 before launching it, and never bypass SmartScreen, Defender, antivirus, or system policy. Windows ARM64 is unsupported. The setup installs below `%LOCALAPPDATA%\CodexUsageSidebar\Current`, creates only a current-user Run-key entry, and leaves the official Codex package read-only.

## Implemented parity

The Windows WPF overlay uses the same official local `codex app-server --stdio` contracts as macOS:

- live remaining percentage, reset countdown, plan, period, Credits, and all Bank entries;
- seven-day Token usage and current-cycle total from `account/usage/read`;
- account name/email fallback and optional avatar URL from `account/read`;
- Simplified Chinese, Traditional Chinese, English, and English fallback for other locales;
- theme-aware plugin icon, synchronized `v0.3.2` version badge, shared countdown emphasis, hover/pin behavior, and GitHub footer link;
- safe degradation when optional Token or account responses are unsupported, malformed, or delayed.

The current v0.3.2 card does not render a Tibo X row. It never reads browser cookies, scrapes X, or sends telemetry.

## Compatibility and safety

There is no fixed Codex file-version allow list. The selector accepts a running Codex build only when its title bar exposes the required semantic UI Automation structure and collision-free geometry. An unknown or incomplete structure hides the overlay instead of guessing coordinates. The process boundary uses a fixed `codex app-server --stdio` argument contract and an isolated `CODEX_HOME`.

Portable .NET tests, payload-manifest validation, installer path/rollback guards, SHA-256 verification, and Windows workflow checks cover the source release. They do not replace target-device validation.

## Remaining real-device matrix

The v0.3.2 asset is published, but it does **not** claim completion of the 130-case Windows real-device matrix. Before asserting complete Windows coverage, collect evidence on Windows 11 AMD64/x64 for:

- collapsed/expanded left, right, and bottom panes; narrow, restored, maximized, and fullscreen windows;
- 100%, 125%, 150%, and 200% DPI; light, dark, and system themes; Simplified Chinese, Traditional Chinese, English, and another locale;
- hover, pin/dismiss, non-activation, Codex restart/update, sleep/resume, app-server recovery, and unsupported UIA fallback;
- install, repair, update, uninstall, Run-key cleanup, checksum/provenance verification, and SmartScreen handling.

Use the [Windows device handoff](WINDOWS-DEVICE-HANDOFF.md) or [Chinese handoff](WINDOWS-DEVICE-HANDOFF.zh-CN.md) to capture sanitized evidence. Continue development with [the Windows Codex continuation guide](WINDOWS-CODEX-CONTINUATION.md).
