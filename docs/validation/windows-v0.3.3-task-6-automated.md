# Windows v0.3.3 Task 6 automated fixture and release-gate evidence

Date: 2026-08-23

## Scope

This record covers the automated fixture matrix and source-level release checks only. It does not
claim any physical-device, signed-in Codex, installation-lifecycle, visual, DPI, or real-device
observation. The formal v0.3.3 setup remains non-publishable.

## TDD evidence

`V033TitlebarFixtureMatrixTests` was added before its fixture contract existed. The focused test
run failed with `FileNotFoundException` for `windows-v033-titlebar-matrix.json`. Once the fixture
was present, the unrecognised-case assertion correctly failed because changing only the
`rounded-e-none` marker still left a valid square composer anchor. The fixture now removes the
composer marker, and the focused run passes 2/2.

## Automated fixture matrix

`windows-v033-titlebar-matrix.json` contains three privacy-safe sampled structures: wide, narrow,
and right-pane. Every structure exercises physical coordinate transforms at 100%, 125%, 150%, and
200% DPI and contains English/Simplified-Chinese semantic labels. The matrix asserts a valid
semantic/profile/titlebar outcome for recognised structures. It also removes the composer marker
for each structure, proves resolution is rejected, and proves the compatibility state machine plus
safe-dock resolver yields a fallback frame when live data and host geometry exist.

## Automatic verification

- Focused matrix test: 2/2 passed.
- `dotnet test plugins/codex-usage-sidebar/windows/CodexUsageSidebar.Windows.sln --no-restore`:
  Core 54/54, Installer 86/86, Windows 121/121.
- `bash tests/test-windows-payload-manifest.sh`: passed positive and negative payload checks.
- `bash plugins/codex-usage-sidebar/tests/test-windows-hook.sh`: passed.
- `bash tests/test-public-repo-windows-source-boundary.sh`: passed.
- `scripts/build-windows-v033-setup.ps1 -PlanOnly`: reports schema-v2 selectors, x64/win-x64,
  `requiresCompleteRealDeviceEvidence: true`, `realDeviceValidated: false`, and
  `publishableInstaller: false`.
- `git diff --check`: passed.

## Deliberate release gate

`verify-windows-v033-setup.ps1 -CandidateDirectory .` exits nonzero with the expected message that
Task 6 real-device validation evidence is required. This is the required outcome in this
environment, not a completed package verification. The remaining physical-device matrix is
specified in [the real-device validation template](windows-v0.3.3-real-device-template.md); until
every row is observed and recorded by a maintainer, formal v0.3.3 setup publication is blocked.
