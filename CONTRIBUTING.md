# Contributing

Contributions are welcome. Please keep changes focused, testable, and safe for users who run the
official Codex desktop app.

## Before opening an issue

1. Check [Troubleshooting](docs/TROUBLESHOOTING.md).
2. Search existing issues.
3. Include macOS version, Codex build, plugin version, and the output of:

   ```bash
   "$HOME/Library/Application Support/CodexUsageSidebar/sidebar-control.sh" status
   ```

Remove usernames and unrelated window content from screenshots and logs.

## Development setup

Requirements: macOS 14+, Apple Silicon, full Xcode, and a running Codex desktop app for live tests.

```bash
git clone https://github.com/Byctor/codex-usage-sidebar.git
cd codex-usage-sidebar/plugins/codex-usage-sidebar
bash scripts/build-companion.sh
bash tests/test-sidebar-control.sh
bash tests/live-app-server-probe.sh
```

## Pull requests

- Add or update tests for behavior changes.
- Keep the companion outside `/Applications/ChatGPT.app`.
- Do not add telemetry, account-token access, or network calls without an explicit design discussion.
- Run `bash scripts/validate-public-repo.sh` from the repository root.
- Explain the user impact, root cause, and verification in the PR description.
- Do not include personal paths, account data, full-screen desktop captures, or generated build trees.

## Commit style

Use concise imperative subjects, for example:

```text
fix: preserve placement during incomplete AX scans
docs: clarify marketplace upgrade flow
```

By participating, you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).
