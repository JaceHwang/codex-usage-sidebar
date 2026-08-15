# Task 4 local acceptance report

## Scope and baseline

- Worktree: `/Users/byctor/plugins/codex-usage-sidebar-public/.worktrees/tibo-x-entry`
- Baseline: `e033751 fix: limit countdown emphasis to reset row`
- No GitHub push was performed.
- The three pre-existing generated install outputs remain deliberately unstaged:
  `plugin.json`, the companion `Info.plist`, and `CodexUsageSidebar` binary.

## Fresh automated verification

All commands below exited successfully on 2026-08-15.

| Check | Result |
| --- | --- |
| `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test --package-path plugins/codex-usage-sidebar/native` | 238 tests, 0 failures |
| `bash plugins/codex-usage-sidebar/tests/test-sidebar-control.sh` | PASS |
| `bash plugins/codex-usage-sidebar/tests/test-signing-identity.sh` | PASS: stable signing identity |
| `bash plugins/codex-usage-sidebar/tests/test-bundle-version.sh` | PASS: manifest and companion are 0.3.0 |
| `bash plugins/codex-usage-sidebar/tests/live-app-server-probe.sh` | `remaining=14 reset_epoch=1787225504 bank_count=0` |
| `uv run --with PyYAML python "$plugin_creator_skill/scripts/validate_plugin.py" plugins/codex-usage-sidebar` | Plugin validation passed |
| `CUS_REBUILT_PAYLOAD=1 bash scripts/validate-public-repo.sh` | Public repository validation passed |
| `git diff --check` | Clean |

Focused post-rebuild link and formatter verification also passed: 10 tests, 0 failures.
`QuotaExternalLinkActivatorTests` asserts the exact event order
`dismiss`, then `open:https://x.com/thsottiaux`.

## Rebuild and local installation

Used the portable plugin-creator path:

```bash
plugin_creator_skill="${CODEX_HOME:-${HOME}/.codex}/skills/.system/plugin-creator"
python3 "$plugin_creator_skill/scripts/update_plugin_cachebuster.py" plugins/codex-usage-sidebar
bash plugins/codex-usage-sidebar/scripts/build-companion.sh
bash plugins/codex-usage-sidebar/scripts/sidebar-control.sh repair \
  --plugin-root "$PWD/plugins/codex-usage-sidebar"
```

- Cachebuster updated to `0.3.0+codex.20260815141240` while preserving product version `0.3.0`.
- The release companion built, was signed, and was repaired into the local installation.
- Repair reported: `pid=39529 version=0.3.0 ... runtime=hidden:no-snapshot`.

## Native visual fixtures

`QuotaDetailCardVisualTests` generated and passed all 5 visual checks, including fixed
seven columns, no horizontal chart scroller, no footer controls, vertical Bank scrolling,
and reset-only countdown emphasis. Twelve PNG fixtures were written to:

`/tmp/codex-quota-reference-t4.uUEMSG`

Representative inspected screenshots:

- Dark Aqua, Simplified Chinese: `/tmp/codex-quota-reference-t4.uUEMSG/tibo-zh-cn-dark.png`
- Aqua, English: `/tmp/codex-quota-reference-t4.uUEMSG/tibo-en-light.png`

Both inspected fixtures show the reference header/Tibo hierarchy, seven visible bars,
no Jace or question-mark footer, and only the reset count uses the orange enlarged
emphasis. The complete set covers English, Simplified Chinese, and Traditional Chinese,
in Aqua and Dark Aqua, with normal and Tibo-hover states.

## Desktop acceptance limitation

The rebuilt companion is installed and running, but direct Codex desktop interaction was
not possible in this execution environment: Computer Use rejected `com.openai.codex` as
not allowed for safety. Consequently these literal UI actions were not independently
clicked in this run: opening the live homepage popover, navigating to Settings and back,
and activating the live Tibo row. Their implementation is covered by the fresh full suite,
the focused exact-URL test, and the native fixture evidence above; a human desktop pass can
complete those final interactions when Codex UI control is available.

## Review follow-up: unavailable token chart slots

The final review found that the unavailable/unsupported and invalid-window
formatter branches returned `days: []`; the native token view also skipped its
chart whenever availability was not `.available`. This violated the fixed
seven-slot reference-chart contract.

The repair preserves availability, unavailable copy, and `totalTokens == 0`,
but derives seven display dates before the current-cycle guard. Unavailable and
unsupported snapshots now produce seven zero-token slots from the allowance
cycle. If the allowance has no valid positive window, `TokenUsageWindow`
provides a safe seven-day fallback ending at `now`. The view always constructs
those seven bars; zero values draw no misleading minimum-height filled bar.

TDD evidence:

- RED: formatter and AppKit visual focused suite failed with empty days and
  zero bar subviews.
- GREEN focused run: formatter/window/visual suites, 22 tests and 0 failures.
- Full package: 242 tests and 0 failures; `git diff --check` clean.

New regressions cover unavailable, unsupported, and invalid-window data,
including the safe current-day-ending fallback. The visual regression asserts
both `QuotaTokenUsageView.barCount == 7` and seven concrete
`QuotaTokenUsageBarView` descendants for unavailable data, while retaining the
unavailable accessibility note.
