<p align="center">
  <img src="docs/images/hero.svg" alt="Codex Usage Sidebar in expanded and collapsed layouts" width="900">
</p>

<h1 align="center">Codex Usage Sidebar</h1>

<p align="center">
  Live Codex quota, reset time, Credits, and Bank details—right where you work.
</p>

<p align="center">
  <a href="README.zh-CN.md">简体中文</a> ·
  <a href="docs/INSTALL.md">Install</a> ·
  <a href="docs/INSTALL_FOR_AGENTS.md">Install with an agent</a> ·
  <a href="docs/TROUBLESHOOTING.md">Troubleshooting</a>
</p>

<p align="center">
  <a href="https://github.com/Byctor/codex-usage-sidebar/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/Byctor/codex-usage-sidebar/actions/workflows/ci.yml/badge.svg"></a>
  <a href="https://github.com/Byctor/codex-usage-sidebar/releases"><img alt="Release" src="https://img.shields.io/github/v/release/Byctor/codex-usage-sidebar"></a>
  <a href="LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/license-MIT-blue.svg"></a>
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-black">
  <img alt="Apple Silicon" src="https://img.shields.io/badge/Apple%20Silicon-arm64-black">
</p>

> [!NOTE]
> This is an independent community project and is not affiliated with or endorsed by OpenAI.

## What it does

Codex Usage Sidebar installs a small native macOS companion outside the signed Codex application.
It shows remaining usage and the next reset time in the Codex desktop UI, follows the active theme,
and updates from Codex's own local `app-server` stream.

| State | Behavior |
| --- | --- |
| Sidebar expanded | A separate quota control sits beside the profile and help controls. |
| Sidebar collapsed | A compact `remaining · reset` control moves to the right titlebar group. |
| Hover | A native detail card shows plan, period, Credits, and every Bank entry with expiry/status. |
| Settings or non-main surface | The companion hides after a completed surface scan. |

<p align="center">
  <img src="docs/images/placement.svg" alt="Placement behavior across expanded, collapsed, and Settings states" width="900">
</p>

## Quick install

Requirements: Codex desktop for macOS, macOS 14 or later, Apple Silicon, and the `codex` CLI.

```bash
codex plugin marketplace add Byctor/codex-usage-sidebar
codex plugin add codex-usage-sidebar@codex-usage-sidebar
```

Start a **new Codex task** after installation. The `SessionStart` hook installs and starts the
companion automatically.

For exact expected output, permission setup, updates, and removal, see
[Install for people](docs/INSTALL.md). If you want Codex or another coding agent to perform the
setup, use [Install with an agent](docs/INSTALL_FOR_AGENTS.md).

## macOS permission

The companion can display from synchronized state without Accessibility access. For precise
main/Settings classification and semantic positioning, enable:

`System Settings → Privacy & Security → Accessibility → Codex Usage Sidebar`

macOS may ask for confirmation. The project never bypasses this system permission and never edits,
injects into, or re-signs `/Applications/ChatGPT.app`.

Official Codex app upgrades do not normally affect this approval. Public builds are currently
ad-hoc signed, so a future companion update that replaces its executable may require you to enable
Accessibility again. Developer ID signing and notarization are planned before calling that approval
permanent.

## Why it survives Codex upgrades

- The companion lives in `~/Library/Application Support/CodexUsageSidebar/`.
- A user LaunchAgent keeps it running across Codex restarts.
- Every session rediscovers the running `com.openai.codex` bundle and current `codex app-server`.
- Plugin updates atomically replace the companion; official app upgrades cannot overwrite it.
- Repair is one command:

```bash
"$HOME/Library/Application Support/CodexUsageSidebar/sidebar-control.sh" repair
```

## Privacy and security

- Reads quota snapshots from the local Codex `app-server` process.
- Does not scrape web pages or read account tokens.
- Does not send telemetry or quota data to a third party.
- Uses Accessibility only for Codex window semantics and placement.
- Keeps all runtime data on the local Mac.

Read the complete [privacy model](docs/PRIVACY.md), [architecture](docs/ARCHITECTURE.md), and
[security policy](SECURITY.md).

## Development

```bash
cd plugins/codex-usage-sidebar
bash scripts/build-companion.sh
bash tests/test-sidebar-control.sh
bash tests/live-app-server-probe.sh   # requires a running Codex desktop app
```

The build runs the Swift test suite, creates an arm64 release app, applies an ad-hoc signature, and
verifies the bundle. See [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.

## Documentation

- [Human installation and operations](docs/INSTALL.md)
- [Agent installation playbook](docs/INSTALL_FOR_AGENTS.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Privacy](docs/PRIVACY.md)
- [Support](SUPPORT.md)
- [Changelog](CHANGELOG.md)

## License

[MIT](LICENSE) © 2026 Jace (Byctor)
