# Continuing Windows Development in Codex

This is the tracked handoff entry point for moving development from macOS to a Windows Codex task.
The source, decisions, and test baseline travel through Git; no local workspace copy or chat history
is required.

## Authoritative state

- Branch: `v0.3.0`
- Stable macOS release: `v0.2.3`; never overwrite or re-upload its release assets
- Windows status: the non-activating WPF overlay is visible on the Windows 11 AMD64/x64 validation
  device and follows movement and resizing. Exact Codex file build `151.0.7922.76` may use its
  controlled relative fallback; unknown builds and unsafe UIA input remain hidden.
- Next phase: complete the canonical 130-case single-monitor real-device matrix and bind both
  release candidates to its immutable source/evidence identities. This release evidence does not
  claim cross-monitor movement, cross-monitor DPI transitions, or negative-coordinate placement.
- Distribution status: the local device-test manager is installable but nonpublishable; no setup may
  ship before the complete release gate passes.

The approved macOS v0.2.3 UI is the Windows visual and interaction source of truth. Windows keeps
the same compact quota/reset control, hover and click-to-pin card, 300-logical-pixel detail layout,
blue version badge, quota color spectrum, emphasized countdown digits, themes, and three languages.
Segoe UI, per-monitor DPI behavior, native focus cues, and high contrast are permitted platform
adaptations, not a redesign.

## Sync on Windows

For a fresh clone in PowerShell:

```powershell
git clone https://github.com/JaceHwang/codex-usage-sidebar.git
Set-Location .\codex-usage-sidebar
git fetch origin
git switch --track origin/v0.3.0
git status --short --branch
git rev-parse HEAD
```

For an existing clean clone:

```powershell
Set-Location C:\path\to\codex-usage-sidebar
git status --short
git fetch origin
git switch v0.3.0
git pull --ff-only
```

Never discard local changes to make the switch. Install Git, the .NET 8 SDK, Visual Studio 2022
Build Tools with the **.NET desktop development** workload, and GitHub CLI. Use a normal desktop
user, not an administrator.

Install the official AMD64 GitHub CLI from the `winget` community source, then authorize it through
GitHub's browser flow. Never put a token in a command, tracked file, or task transcript:

```powershell
winget install --id GitHub.cli --exact --source winget `
  --accept-source-agreements --accept-package-agreements
gh auth login --hostname github.com --git-protocol https --web --skip-ssh-key
gh auth status --hostname github.com
gh repo view JaceHwang/codex-usage-sidebar --json nameWithOwner,defaultBranchRef
gh run list --repo JaceHwang/codex-usage-sidebar --limit 1
```

GitHub CLI is required for development/release operations, not for normal plugin use.

On the current validation device, Git Bash login shells use a controlled `~/.profile`; the
auto-generated `~/.bash_profile` is intentionally absent. The profile sources the existing
`~/.bashrc`, puts the installed Miniconda and GitHub CLI directories on `PATH`, and provides a
`python3` function backed by Miniconda. Run Bash-based release gates through a login shell so this
configuration is loaded:

```powershell
& 'D:\app\Git\bin\bash.exe' -lc `
  'cd /c/path/to/codex-usage-sidebar && tests/test-v030-release-candidate-workflow.sh'
```

This user-level shell configuration is development-machine setup; do not copy it into the plugin
payload or store GitHub credentials in it.

## Start the Windows Codex task

Open the repository root in Codex and begin with:

```text
Continue Codex Usage Sidebar Windows v0.3.0. Read docs/WINDOWS-CODEX-CONTINUATION.md,
docs/superpowers/specs/2026-08-13-v0.3.0-complete-release-chain-design.md,
docs/superpowers/plans/2026-08-13-v0.3.0-complete-release-chain.md, and
docs/WINDOWS-DEVICE-HANDOFF.md in full.
The macOS v0.2.3 UI is the visual source of truth. Verify HEAD and the baseline tests first, then
capture the default sanitized UIA report from a disposable Codex task. Unknown UIA structures must
hide the overlay. Use TDD for the WPF overlay, placement, and localized installer UI, and do not
change or republish macOS v0.2.3 assets.
```

Run the baseline from the repository root:

```powershell
$ErrorActionPreference = 'Stop'
dotnet restore .\plugins\codex-usage-sidebar\windows\CodexUsageSidebar.Windows.sln
dotnet test .\plugins\codex-usage-sidebar\windows\CodexUsageSidebar.Windows.sln `
  --configuration Release --nologo
dotnet build `
  .\plugins\codex-usage-sidebar\windows\src\CodexUsageSidebar.Windows\CodexUsageSidebar.Windows.csproj `
  --configuration Release --framework net8.0-windows10.0.19041.0 --no-restore --nologo
```

Then follow the exact privacy, checksum, probe, screenshot, DPI, language, theme, and layout matrix
in [the real-device handoff](WINDOWS-DEVICE-HANDOFF.md). Convert the sanitized capture into
versioned selector/layout fixtures and failing tests before enabling the production overlay.

Push every verified phase back to the same branch. Git commits, CI results, and provenance—not a
chat transcript or copied archive—are the cross-machine source of truth.
