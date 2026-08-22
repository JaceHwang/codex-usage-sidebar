<p align="center">
  <img src="docs/images/hero.svg" alt="Codex Usage Sidebar adaptive titlebar placement" width="900">
</p>

<h1 align="center">Codex Usage Sidebar</h1>

<p align="center">
  Live Codex quota, reset time, Credits, and Bank details in the Codex titlebar.
</p>

<p align="center">
  <a href="README.zh-CN.md">简体中文</a> ·
  <a href="docs/INSTALL.md">Install</a> ·
  <a href="docs/INSTALL_FOR_AGENTS.md">Install with an agent</a> ·
  <a href="docs/TROUBLESHOOTING.md">Troubleshooting</a>
</p>

<p align="center">
  <a href="https://github.com/JaceHwang/codex-usage-sidebar/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/JaceHwang/codex-usage-sidebar/actions/workflows/ci.yml/badge.svg"></a>
  <a href="https://github.com/JaceHwang/codex-usage-sidebar/releases"><img alt="Release" src="https://img.shields.io/github/v/release/JaceHwang/codex-usage-sidebar"></a>
  <a href="LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/license-MIT-blue.svg"></a>
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-black">
  <img alt="Apple Silicon" src="https://img.shields.io/badge/Apple%20Silicon-arm64-black">
</p>

> [!NOTE]
> This is an independent community project and is not affiliated with or endorsed by OpenAI.

## Platform status

| Platform | Status | Distribution |
| --- | --- | --- |
| macOS 14+ Apple Silicon | Stable v0.2.3 | Signed companion plus v0.2.3 DMG |
| Windows 11 AMD64 (`x64`) | v0.3.2 release | Unsigned `x64` setup asset; Windows ARM64 is out of scope |

Windows `v0.3.2` is the Windows 11 AMD64/x64 release line. It carries the macOS-visible quota card
model (token usage, account identity, theme-aware icon, reset countdown, Credits, Bank details, and
the GitHub footer) without the Tibo X row. The shared quota contracts, .NET core, Win32 window
boundary, sanitized UI Automation probe, per-user installer backend, payload digest verification,
and Windows CI preserve the stable macOS payload. The v0.3.2 Windows asset is locally packaged and
includes quick-prerelease validation metadata; the 130-case Windows manual matrix is still incomplete,
so this release does not claim complete real-device validation. The selector no longer rejects a Codex build
solely because its file version changed; it still requires a safe semantic UI Automation structure,
and hides the overlay instead of guessing coordinates when that structure is unavailable. See [Windows beta development](docs/WINDOWS-BETA.md)
for development and validation details, and [Windows real-device diagnostic handoff](docs/WINDOWS-DEVICE-HANDOFF.md)
for the device procedure. To move the active work into Codex on a Windows computer, follow the
[Windows Codex continuation guide](docs/WINDOWS-CODEX-CONTINUATION.md); the Git branch and its
verified commit history are the handoff source of truth. The complete feature matrix is in
[Windows v0.3.1 parity notes](docs/WINDOWS-V031-PARITY.md).

## Current v0.3.1 appearance

<p align="center">
  <img src="docs/images/quota-popover-v0.3.1-en-light.png" alt="Codex Usage Sidebar v0.3.1 quota popover with token usage, themed app icon, and GitHub footer link in the light theme" width="48%">
  <img src="docs/images/quota-popover-v0.3.1-en-dark.png" alt="Codex Usage Sidebar v0.3.1 quota popover with token usage, themed app icon, and GitHub footer link in the dark theme" width="48%">
</p>

<p align="center"><em>Current light theme · Current dark theme</em></p>

These v0.3.1 captures are generated from the current native AppKit card and bundled theme assets. They
show the Codex account identity, seven-day token-usage chart, emphasized reset countdown, themed
quota icon, borderless compact GitHub link, and the light/dark separator and shadow materials.

## Adaptive titlebar placement

<p align="center">
  <img src="docs/images/adaptive-titlebar-nearby-dark.png" alt="Quota control moved into the nearest free titlebar slot before Open Location" width="96%">
</p>

<p align="center"><em>Enough room: the control occupies the nearest collision-free slot and keeps an 8-point gap.</em></p>

<p align="center">
  <img src="docs/images/adaptive-titlebar-fallback-dark.png" alt="Quota control moved to the safe right-side titlebar fallback" width="96%">
</p>

<p align="center"><em>Not enough room: the control moves immediately to the reserved right-side titlebar position and remains visible while the middle tab continues shrinking.</em></p>

## What it does

Codex Usage Sidebar installs a small native macOS companion outside the signed Codex application.
It reads quota updates from Codex's local `app-server`, follows the current light or dark theme,
and renders one non-activating control in the nearest safe titlebar slot.

| Situation | Behavior |
| --- | --- |
| Left, right, or bottom pane changes | The quota control prefers the native **Open Location** anchor, slides left around occupied controls, and moves to the reserved right-side position only when the local titlebar cannot fit it. |
| Window moves or resizes | The collision-aware layout is sampled every 0.1 seconds, so the control tracks the available titlebar space without overlapping native controls or titles. |
| Hover | A native detail card shows the synchronized plugin version, account identity, theme icon, plan, period, daily and total token usage, Credits, and every Bank entry with status and expiry. |
| Click | The detail card stays pinned until the quota control is clicked again; hover behavior remains available. |
| Footer GitHub button | Opens the project repository at [github.com/JaceHwang/codex-usage-sidebar](https://github.com/JaceHwang/codex-usage-sidebar). The resting button blends into the footer; hover adds only a soft rounded shadow. |
| Quota changes | Percentage color follows the exact 100% green, 49% orange, and 10% red palette while the filled bar reveals the matching spectrum. |
| Codex language changes | The control and detail card follow Codex's effective Simplified Chinese, Traditional Chinese, or English locale within one second. |

The old sidebar-footer copy and all sidebar-state synchronization code are removed. There is only one
quota control.

<p align="center">
  <img src="docs/images/placement.svg" alt="Collision-aware placement across pane and window changes" width="900">
</p>

## Quick install

Choose the platform-specific installation path below. Windows support is Windows 11 AMD64/x64 only;
Windows ARM64 is not supported. The v0.3.2 setup uses explicit unsigned-install safeguards and must
be verified by SHA-256 before launch.

### Windows 11 AMD64/x64

Requirements: Windows 11 on AMD64/x64, Codex desktop for Windows installed and signed in, and
PowerShell. There is no fixed minimum Codex file version. New Codex builds are accepted when their
title bar exposes the validated semantic UI structure; an unknown or unsafe structure remains
fail-hidden until it can be validated.

#### Manual setup install

1. Open the [v0.3.2 GitHub Release](https://github.com/JaceHwang/codex-usage-sidebar/releases/tag/v0.3.2) and download only
   `codex-usage-sidebar-v0.3.2-windows-x64-setup.exe` plus `WINDOWS-V032-SHA256SUMS.txt`.
2. Verify the setup SHA-256 before launching it:

   ```powershell
   Get-FileHash .\codex-usage-sidebar-v0.3.2-windows-x64-setup.exe -Algorithm SHA256 | Select-Object -ExpandProperty Hash
   ```

   Compare it case-insensitively with the matching entry in `WINDOWS-V032-SHA256SUMS.txt`.
3. Run the verified setup for the current user:

   ```powershell
   Start-Process .\codex-usage-sidebar-v0.3.2-windows-x64-setup.exe
   ```

4. The setup is intentionally unsigned (`NotSigned`), so Windows may show **Unknown publisher**.
   Only after the SHA-256 matches, choose **More info**, then **Run anyway**.
5. Never disable Defender, SmartScreen, antivirus, or system policy. If the digest differs, delete
   the file and download it again from the release. The companion installs under
   `%LOCALAPPDATA%\CodexUsageSidebar\Current` and starts from the current-user Run key.

If Codex exposes an unsupported UI Automation structure, the Windows overlay stays hidden instead
of guessing coordinates. See [Installation and operations](docs/INSTALL.md) for `--repair`,
`--uninstall`, status output, and validation boundaries.

#### Agent-assisted automatic install

Give your Windows coding agent this task:

```text
Install Codex Usage Sidebar v0.3.2 from the GitHub Release on this Windows 11 AMD64/x64 machine.
Download codex-usage-sidebar-v0.3.2-windows-x64-setup.exe and WINDOWS-V032-SHA256SUMS.txt only,
verify the setup SHA-256 against the matching release entry, run the setup only if the digest matches, and report the install
path and runtime status. Do not disable or bypass Defender, SmartScreen, antivirus, or system policy.
If an installer, SmartScreen, uninstall, or Windows security dialog appears, stop and ask me for
immediate confirmation before clicking it.
```

An agent can automate the download, checksum comparison, and setup launch, but it must not bypass
Windows trust UI or claim the setup lifecycle was locally validated unless it actually completed
that validation on the target machine. See [Install with an agent](docs/INSTALL_FOR_AGENTS.md) for
the deterministic playbook.

### macOS 14+ Apple Silicon

Requirements: Codex desktop for macOS, macOS 14 or later, Apple Silicon, and the `codex` CLI with
plugin support. The installer does not pin a Codex version. It searches the standard locations and
the current `PATH`; a CLI release is compatible when it provides the `plugin marketplace` and
`plugin add` commands used by the installer.

#### Download the installer

1. Download [`codex-usage-sidebar-v0.2.3-macos-arm64.dmg`](https://github.com/JaceHwang/codex-usage-sidebar/releases/download/v0.2.3/codex-usage-sidebar-v0.2.3-macos-arm64.dmg) from the v0.2.3 release **Assets**.
2. Open the DMG, then open **Codex Usage Sidebar Installer**.
3. This raw download is not notarized. If macOS blocks it, right-click the installer in Finder and choose Open.
4. Click **Install**, finish the guided Codex login, and enable Accessibility for **Codex Usage Sidebar** when macOS asks.
5. Click **Verify** in the installer to confirm that the managed companion is running.

The installer keeps its files outside the Codex application and never copies your normal `~/.codex`
credentials. See [Installation and operations](docs/INSTALL.md) for repair, update, and uninstall
behavior.

### Advanced: manual marketplace installation

```bash
codex plugin marketplace add JaceHwang/codex-usage-sidebar
codex plugin add codex-usage-sidebar@codex-usage-sidebar
```

Start a **new Codex task** after installation. Codex loads plugins at the task boundary, and the
`SessionStart` hook installs and starts the companion. This follows the same task-boundary model
described in the [official Codex plugin workflow](https://developers.openai.com/learn/developers-codex-plugin/).

The companion uses its own Codex home so it never copies credentials from your normal `~/.codex`.
Authorize that isolated home once:

```bash
env CODEX_HOME="$HOME/Library/Application Support/CodexUsageSidebar/CodexHome" codex login
```

Then enable Accessibility for **Codex Usage Sidebar** when macOS asks. See
[Installation and operations](docs/INSTALL.md) for exact status, update, repair, and removal steps.

## Collision-aware positioning

The companion scans the accessibility branches that can affect titlebar placement. It reads labels
and frames only from eligible buttons and static title text, and uses unlabeled structural group
frames in the relevant region to detect pane boundaries. It then applies this placement policy:

```text
1. Prefer quota.maxX = openLocation.minX - 8 pt.
2. If that frame intersects another titlebar item, slide left to the nearest free slot.
3. If no complete slot remains before a title barrier, use the reserved right-side fallback.
```

The toolbar-item scan includes the full horizontal reach of the 164-point control but rejects items
outside the 46-point titlebar. Structural groups are considered only as geometry for pane-boundary
detection; their labels and text are never read. This keeps resizing responsive without reading
conversation bodies.
Degenerate elements clipped to a 1-point line at the top of a fullscreen window are ignored rather
than mistaken for visible title text. Geometry eligibility is checked before any label is read, and
every 0.1-second placement tick re-scans eligible titlebar geometry even when the semantic anchor
itself is unchanged. An intentional fallback replaces an obsolete retained anchor immediately; a
transient incomplete scan still preserves the last valid placement for at most 0.75 seconds. The
companion never modifies Codex internals.

## Live details

- Remaining percentage and next reset time are always visible in the compact control.
- A compact outlined badge beside the quota-card title reads the app bundle version, so the
  visible UI and installed code can be identified without opening a terminal.
- The hover card includes plan, period, Credits, Bank availability, every Bank credit, expiry, and
  status.
- The compact and hover percentages use the same continuously interpolated state color:
  `100%` green, `49%` orange, and `10%` red.
- The progress fill clips a fixed red-to-orange-to-green spectrum to the live remaining percentage;
  the unused portion stays theme-aware neutral gray.
- Local notifications update the display immediately; bounded refresh and stream recovery protect
  against missed updates.

## Language matching

Version 0.3.1 follows the language Codex is actually displaying. An explicit Codex language choice
is authoritative; when Codex is set to **Auto**, the running renderer's resolved locale is used.
Codex preferences and the macOS preferred language remain safe startup fallbacks.

| Effective Codex locale | Plugin UI |
| --- | --- |
| Simplified Chinese (`zh-Hans`, `zh-CN`, `zh-SG`) | 简体中文 |
| Traditional Chinese (`zh-Hant`, `zh-TW`, `zh-HK`, `zh-MO`) | 繁體中文 |
| English (`en-*`) | English |
| Any other locale | English |

There is no separate plugin language switch. The companion checks the effective locale every
second, so both a visible and a click-pinned detail card update without reinstalling the plugin.

## Why it survives Codex upgrades

- The companion lives in `~/Library/Application Support/CodexUsageSidebar/`, outside the official
  app bundle.
- A user LaunchAgent keeps it running across Codex restarts.
- Host discovery finds the currently running `com.openai.codex` bundle and its current
  `codex app-server` executable.
- Plugin updates fingerprint and atomically replace the companion; Codex app upgrades cannot
  overwrite it.
- The copied payload is re-signed with the stable local identity when available, keeping the same
  Accessibility code identity across plugin reinstalls.
- Repair remains one command:

```bash
"$HOME/Library/Application Support/CodexUsageSidebar/sidebar-control.sh" repair
```

macOS remains the authority for Accessibility approval and may ask again after a security-policy or
signature change.

## Privacy and security

- Reads quota snapshots from the local Codex `app-server` process over stdio.
- Uses an isolated `CodexHome`; credentials are created by the official `codex login` flow.
- Does not scrape web pages, inject into Codex, read conversation text, or send telemetry.
- Reads only the running Codex renderer's locale argument in memory for language matching; raw
  process arguments are never written to diagnostics or logs.
- Reads labels and frames only for eligible titlebar controls/static text, plus unlabeled structural
  group frames in the relevant region for pane-boundary detection.
- Keeps runtime files under the user's Application Support directory.

Read the complete [privacy model](docs/PRIVACY.md), [architecture](docs/ARCHITECTURE.md), and
[security policy](SECURITY.md).

## Status and diagnostics

```bash
"$HOME/Library/Application Support/CodexUsageSidebar/sidebar-control.sh" status
```

A healthy precise-positioning result includes the state from the actual LaunchAgent process:

```text
pid=12345 version=0.3.1 runtime=shown placement=content-header anchor=labeledControl
language=simplifiedChinese language_source=process
indicator=654,1003,164,46 ... cached:false,source:labeledControl,edge:826
installed and loaded: .../Codex Usage Sidebar.app
```

For `openLocation`, `labeledControl`, or `rightPaneBoundary`, the indicator's right edge equals
`edge - 8`. A `fallback` with a resolved edge is an intentional move to the safe right-side slot,
not an error. The runtime version must match the badge in the hover card.

## Build provenance

The marketplace companion is promoted from the exact artifact produced by GitHub Actions.
[`assets/PROVENANCE.json`](plugins/codex-usage-sidebar/assets/PROVENANCE.json) records the source
commit, workflow run, artifact digest, archive digest, executable SHA-256, and code-directory hash.
CI verifies the pinned payload before independently rebuilding and testing the source.

## Development

```bash
cd plugins/codex-usage-sidebar
bash scripts/build-companion.sh
bash tests/test-sidebar-control.sh
bash tests/test-signing-identity.sh
bash tests/live-app-server-probe.sh   # requires isolated CodexHome login

cd ../..
CUS_ALLOW_SOURCE_AHEAD=1 bash scripts/validate-public-repo.sh
```

The build runs the complete Swift suite, produces an arm64 release app, selects the stable local
signing identity when available, and otherwise applies the deterministic ad-hoc requirement used by
CI. See [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.

## Documentation

- [Human installation and operations](docs/INSTALL.md)
- [Agent installation playbook](docs/INSTALL_FOR_AGENTS.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Windows beta development](docs/WINDOWS-BETA.md)
- [Windows real-device diagnostic handoff](docs/WINDOWS-DEVICE-HANDOFF.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Privacy](docs/PRIVACY.md)
- [Support](SUPPORT.md)
- [Changelog](CHANGELOG.md)

## License

[MIT](LICENSE) © 2026 Jace
