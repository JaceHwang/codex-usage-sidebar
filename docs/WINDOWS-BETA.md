# Windows v0.3.1 Parity and Device Gate

## Current status

The Windows line is an explicitly gated AMD64 parity build (`x64` in .NET and artifact names). It is
based on the current macOS-visible v0.3.1 card without altering or replacing the v0.2.3 macOS
plugin, companion, DMG, or GitHub Release assets. Windows ARM64 is outside the build, device,
packaging, and publication scope of v0.3.1.

Implemented and testable without a Windows Codex session:

- shared, sanitized app-server rate-limit and placement contracts;
- .NET 8 decoding, language mapping, compact duration segments, quota colors, freshness,
  hover/pin interaction, and collision-aware horizontal placement;
- app-server JSON-RPC initialization, reads, notifications, and supplementary Bank-data merging;
- fake-driven host-window, title-bar scanner, DPI, and non-activating overlay contracts;
- fixed-argument `codex app-server --stdio` process launching with an isolated `CODEX_HOME`;
- Win32 Codex window discovery and a bounded UI Automation diagnostic probe;
- a semantic title-bar selector that is no longer gated by the Codex file version; unknown or
  incomplete trees remain hidden instead of using a coordinate fallback;
- non-activating WPF compact/detail surfaces and a three-language WPF installer shell whose default
  development action refuses to install without a validated payload;
- the macOS-visible quota model on Windows: seven-day Token usage, account identity, theme-aware
  quota icon, reset countdown emphasis, Credits, Bank details, and a borderless GitHub footer link;
- an intentional Windows difference: the Tibo X information row is not rendered;
- per-user Windows path planning, exact uninstall guards, autostart plans, atomic payload
  replacement, rollback, link/reparse-point rejection, and full-file SHA-256 verification;
- a Windows 2025 CI job that builds and uploads only a self-contained diagnostic candidate.

Not yet claimed as complete:

- selector and placement validation outside the single measured restored-window, 200% DPI sample;
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
    │   ├── uia/
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

## Legacy diagnostic candidate

The `Windows beta diagnostic candidate` workflow produces:

```text
codex-usage-sidebar-v0.3.0-beta.1-windows-x64-diagnostic.zip
WINDOWS-BETA-SHA256SUMS.txt
WINDOWS-BETA-PROVENANCE.json
```

This legacy diagnostic artifact is not an installer. Its provenance explicitly sets
`realDeviceValidated=false` and `publishableInstaller=false`. On a Windows 11 AMD64 test device (`x64` in artifact metadata) with
Codex open and signed in,
extract it and run:

```powershell
CodexUsageSidebar.Control.exe probe C:\Temp\codex-usage-sidebar-probe.json
```

Use the exact privacy, checksum, layout, theme, language, DPI, screenshot, and handoff procedure in
[Windows real-device diagnostic handoff](WINDOWS-DEVICE-HANDOFF.md). A Simplified Chinese version
is available in [Windows 实机诊断交接手册](WINDOWS-DEVICE-HANDOFF.zh-CN.md).

The default report assigns per-report random HMAC tokens to executable paths and UIA names, so
equal values can be correlated only inside that single report. Add `--include-text` only when the person
collecting the report intentionally agrees to include visible UI Automation names; conversation
content should be closed or replaced with a disposable task first.

To continue the implementation in Codex on a Windows computer, use the tracked
[Windows Codex continuation guide](WINDOWS-CODEX-CONTINUATION.md) or its
[Simplified Chinese version](WINDOWS-CODEX-CONTINUATION.zh-CN.md). It records the exact branch,
approved macOS visual baseline, environment checks, first prompt, baseline commands, and safe
cross-machine Git workflow.

## Required real-device gate

The v0.3.1 setup package remains blocked until all of these pass on the real Windows Codex client:

- expanded and collapsed left, right, and bottom panes;
- narrow, wide, maximized, restored, fullscreen, and multi-monitor windows;
- 100%, 125%, 150%, and 200% display scaling;
- light, dark, and system themes;
- Simplified Chinese, Traditional Chinese, English, and an unsupported-locale fallback;
- hover, click-to-pin, second-click dismissal, keyboard focus, and non-activation;
- Codex restart, update, sleep/resume, app-server authorization, and stream recovery;
- per-user install, repair, upgrade, uninstall, checksum, provenance, and Windows signing checks.

The captured tree remains a versioned diagnostic fixture, not a version allow-list. A changed Codex
build may use the semantic selector immediately when its structure is safe; unknown or incomplete
trees still hide the overlay and request a new diagnostic capture instead of guessing a coordinate
or overlapping native UI.

The first sanitized fixture records one Windows 11 sample from the `OpenAI.Codex` package: the
visible host process is `ChatGPT.exe` with Codex product identity, file build `151.0.7922.76`, at
200% scaling. The PMv2-aware default-redacted report uses physical screen pixels end to end and has
SHA-256 `65e519a71da6c7dc422253a33f30ecaabe175499a51254f9c6eb00983f721f7c`.
This is enough to exercise the semantic selector and its measured fallback, but it is not evidence for the
remaining sidebar, window, theme, language, scaling, focus, lifecycle, or installer matrix.

## v0.3.1 final release shape

After the gate passes, the installer pipeline will publish a prerelease asset named:

```text
codex-usage-sidebar-v0.3.1-windows-x64-setup.exe
```

It will install under `%LOCALAPPDATA%\CodexUsageSidebar`, register only a per-user startup entry,
keep the official Codex application read-only, verify every bundled file and its Codex runtime
provenance, and expose install, repair, status, probe, and uninstall actions.
