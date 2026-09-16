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
git clone https://github.com/JaceHwang/codex-usage-sidebar.git
cd codex-usage-sidebar
git switch -c codex/feat/your-change
./governance doctor
cd plugins/codex-usage-sidebar
bash scripts/build-companion.sh
bash tests/test-sidebar-control.sh
bash tests/test-signing-identity.sh
bash tests/test-bundle-version.sh
bash tests/test-build-sdk.sh
bash tests/live-app-server-probe.sh
```

## Pull requests

- Add or update tests for behavior changes.
- Keep the companion outside the official Codex application bundle.
- Keep companion authentication isolated from the normal `~/.codex` home.
- Do not add telemetry or direct network calls without an explicit design discussion.
- Work on `codex/<type>/<kebab-case>`, never directly on `main`. Run `./governance doctor` before
  code changes and `./governance check all` before pushing; do not bypass hooks or weaken checks.
- Product versions are managed only through generated Release Please PRs. An unpublished working
  candidate or local screenshot version is not a release.
- Update both READMEs and the [current feature/design docs](docs/CURRENT_FEATURES.md) when behavior
  changes. Generate native example images using the [documented fixture workflow](docs/images/current/README.md),
  then inspect them before replacing references. Preserve historical release evidence.
- Explain the user impact, root cause, and verification in the PR description.
- Do not include personal paths, account data, full-screen desktop captures, or generated build trees.

## Commit style

Use English Conventional Commit subjects and Conventional Commit PR titles, for example:

```text
fix: keep the exact Open Location gap while panes move
docs: clarify isolated Codex login
```

By participating, you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).
