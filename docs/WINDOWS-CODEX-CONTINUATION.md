# Continuing Windows Development in Codex

This is the tracked handoff entry point for moving development from macOS to a Windows Codex task.
The source, decisions, and test baseline travel through Git; no local workspace copy or chat history
is required.

## Authoritative state

- Branch: `codex/v0.3.0-beta.1`
- Stable macOS release: `v0.2.3`; never overwrite or re-upload its release assets
- Windows status: portable core, Win32/UIA diagnostic boundary, installer backend, integrity checks,
  and diagnostic CI are implemented
- Next phase: bind the real Codex UIA tree, then build and validate the WPF overlay and localized
  installer UI on Windows
- Distribution status: diagnostic candidate only; it is not an installer

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
git switch --track origin/codex/v0.3.0-beta.1
git status --short --branch
git rev-parse HEAD
```

For an existing clean clone:

```powershell
Set-Location C:\path\to\codex-usage-sidebar
git status --short
git fetch origin
git switch codex/v0.3.0-beta.1
git pull --ff-only
```

Never discard local changes to make the switch. Install Git, the .NET 8 SDK, and Visual Studio 2022
Build Tools with the **.NET desktop development** workload. Use a normal desktop user, not an
administrator.

## Start the Windows Codex task

Open the repository root in Codex and begin with:

```text
Continue Codex Usage Sidebar Windows v0.3.0-beta.1. Read docs/WINDOWS-CODEX-CONTINUATION.md,
the Windows design and plan under docs/superpowers, and docs/WINDOWS-DEVICE-HANDOFF.md in full.
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
