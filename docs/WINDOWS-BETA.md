# Windows v0.3.0-beta.1 Development

## Current status

The Windows line is an explicitly gated beta. It is based on the latest stable Mac source but does
not alter or replace the v0.2.3 plugin, companion, DMG, or GitHub Release assets.

Implemented and testable without a Windows Codex session:

- shared, sanitized app-server rate-limit and placement contracts;
- .NET 8 decoding, language mapping, compact duration segments, quota colors, freshness,
  hover/pin interaction, and collision-aware horizontal placement;
- app-server JSON-RPC initialization, reads, notifications, and supplementary Bank-data merging;
- fake-driven host-window, title-bar scanner, DPI, and non-activating overlay contracts;
- fixed-argument `codex app-server --stdio` process launching with an isolated `CODEX_HOME`;
- Win32 Codex window discovery and a bounded UI Automation diagnostic probe;
- per-user Windows path planning, exact uninstall guards, autostart plans, atomic payload
  replacement, rollback, link/reparse-point rejection, and full-file SHA-256 verification;
- a Windows 2025 CI job that builds and uploads only a self-contained diagnostic candidate.

Not yet claimed as complete:

- production UIA selectors for the current Windows Codex title bar;
- WPF visual parity under real light/dark themes and DPI scaling;
- a publishable `setup.exe` or GitHub prerelease.

## Resulting repository tree

```text
codex-usage-sidebar-public/
├── .github/workflows/
│   ├── ci.yml
│   ├── publish-installer.yml
│   └── windows-beta.yml
├── docs/
│   └── WINDOWS-BETA.md
├── scripts/
│   ├── build-windows-payload-manifest.py
│   └── verify-windows-payload.py
├── tests/
│   ├── test-windows-beta-workflow.sh
│   └── test-windows-payload-manifest.sh
└── plugins/codex-usage-sidebar/
    ├── contracts/
    │   ├── rate-limits/
    │   └── placement/
    ├── hooks/hooks.json
    ├── native/
    ├── scripts/
    │   └── sidebar-control-windows.ps1
    ├── tests/
    │   └── test-windows-hook.sh
    └── windows/
        ├── CodexUsageSidebar.Windows.sln
        ├── Directory.Build.props
        ├── src/
        │   ├── CodexUsageSidebar.Core/
        │   ├── CodexUsageSidebar.Windows/
        │   ├── CodexUsageSidebar.Control/
        │   └── CodexUsageSidebar.Installer/
        └── tests/
            ├── CodexUsageSidebar.Core.Tests/
            ├── CodexUsageSidebar.Windows.Tests/
            └── CodexUsageSidebar.Installer.Tests/
```

## Diagnostic candidate

The `Windows beta diagnostic candidate` workflow produces:

```text
codex-usage-sidebar-v0.3.0-beta.1-windows-x64-diagnostic.zip
WINDOWS-BETA-SHA256SUMS.txt
WINDOWS-BETA-PROVENANCE.json
```

This artifact is not an installer. Its provenance explicitly sets `realDeviceValidated=false` and
`publishableInstaller=false`. On a future Windows 11 x64 test device with Codex open and signed in,
extract it and run:

```powershell
CodexUsageSidebar.Control.exe probe C:\Temp\codex-usage-sidebar-probe.json
```

The default report assigns per-report random HMAC tokens to executable paths and UIA names, so
equal values can be correlated only inside that single report. Add `--include-text` only when the person
collecting the report intentionally agrees to include visible UI Automation names; conversation
content should be closed or replaced with a disposable task first.

## Required real-device gate

The setup package remains blocked until all of these pass on the real Windows Codex client:

- expanded and collapsed left, right, and bottom panes;
- narrow, wide, maximized, restored, fullscreen, and multi-monitor windows;
- 100%, 125%, 150%, and 200% display scaling;
- light, dark, and system themes;
- Simplified Chinese, Traditional Chinese, English, and an unsupported-locale fallback;
- hover, click-to-pin, second-click dismissal, keyboard focus, and non-activation;
- Codex restart, update, sleep/resume, app-server authorization, and stream recovery;
- per-user install, repair, upgrade, uninstall, checksum, provenance, and Windows signing checks.

The captured tree becomes a versioned selector fixture. Unknown Codex builds must hide the overlay
and request a new diagnostic capture instead of guessing a coordinate or overlapping native UI.

## Final release shape

After the gate passes, the installer pipeline will publish a prerelease asset named:

```text
codex-usage-sidebar-v0.3.0-beta.1-windows-x64-setup.exe
```

It will install under `%LOCALAPPDATA%\CodexUsageSidebar`, register only a per-user startup entry,
keep the official Codex application read-only, verify every bundled file and its Codex runtime
provenance, and expose install, repair, status, probe, and uninstall actions.
