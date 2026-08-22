# Continuing v0.3.2 Windows development in Codex

## Authoritative state

- Branch: `v0.3.2`; use Git history and the exact commit SHA as the handoff source of truth.
- Release: v0.3.2 has macOS arm64 and Windows 11 AMD64/x64 assets. Do not move the `v0.3.2` tag, replace release assets, or alter the official Codex installation.
- Current gap: portable Windows source gates pass, while the full Windows 11 real-device UIA/DPI/lifecycle/install matrix remains unverified.
- Visible parity: rate limit, Token usage, account identity, localized compact/detail UI, themed icon, reset emphasis, Credits, Bank, and GitHub footer. The current v0.3.2 card does not render Tibo X.

## Sync safely

```powershell
git clone https://github.com/JaceHwang/codex-usage-sidebar.git
Set-Location .\codex-usage-sidebar
git fetch origin --prune
git switch --track origin/v0.3.2
git pull --ff-only
git status --short --branch
git rev-parse HEAD
```

For an existing clone, inspect `git status --short` first. Do not use `reset --hard` or discard another developer's files. Then run `git fetch origin --prune`, `git switch v0.3.2`, and `git pull --ff-only`.

## Required Windows environment

- Windows 11 AMD64/x64 and the signed-in Codex desktop client;
- Git for Windows, .NET 8 SDK, and Visual Studio 2022 or Build Tools with the .NET desktop workload;
- optional GitHub CLI for inspecting Actions and Release assets.

Do not run Codex, PowerShell, or the setup as Administrator. Windows ARM64 is out of scope.

## First Codex task

Open the repository root in Codex and use this initial task:

```text
Continue Codex Usage Sidebar v0.3.2 Windows validation. Read docs/WINDOWS-BETA.md,
docs/WINDOWS-DEVICE-HANDOFF.md, docs/WINDOWS-V031-PARITY.md, and docs/ARCHITECTURE.md.
First confirm the v0.3.2 Git HEAD, run the documented .NET build/tests, and collect only a
sanitized UIA report from a disposable Codex task. Unknown or unsafe UIA structures must hide the
overlay; do not guess coordinates or publish/replace release assets. Record Windows device evidence
before changing selectors, installer behavior, or compatibility claims.
```

## Baseline commands

```powershell
$ErrorActionPreference = 'Stop'
dotnet restore .\plugins\codex-usage-sidebar\windows\CodexUsageSidebar.Windows.sln
dotnet build .\plugins\codex-usage-sidebar\windows\CodexUsageSidebar.Windows.sln --configuration Release --no-restore --nologo
dotnet test .\plugins\codex-usage-sidebar\windows\CodexUsageSidebar.Windows.sln --configuration Release --no-build --nologo
```

Run the real-device matrix from [Windows device handoff](WINDOWS-DEVICE-HANDOFF.md) after the baseline is green. Commit small verified changes to a feature branch and push them; on macOS, resume with `git fetch origin` and `git pull --ff-only`.
