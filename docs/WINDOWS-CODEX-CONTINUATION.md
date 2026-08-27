# Continuing Windows maintenance in Codex

## Authoritative state

- Branch: `main`; use Git history and the exact commit SHA as the source of truth.
- Release: v0.3.3 is the published Windows 11 AMD64/x64 release. Do not move the `v0.3.3` tag,
  replace release assets, or alter the official Codex installation.
- Release evidence: the published package is bound to the complete 85-case real-device record in
  `docs/validation/windows-v0.3.3.json`; unknown UIA structures remain fail-hidden.
- Compatibility: the installer can consume signed HTTPS compatibility-pack updates. Users should
  not edit `selectors.json` manually; report an unknown structure through the diagnostic handoff.

## Sync safely

```powershell
git clone https://github.com/JaceHwang/codex-usage-sidebar.git
Set-Location .\codex-usage-sidebar
git fetch origin --prune
git switch --track origin/main
git pull --ff-only
git status --short --branch
git rev-parse HEAD
```

For an existing clone, inspect `git status --short` first. Do not use `reset --hard` or discard
another developer's files. Then run `git fetch origin --prune`, `git switch main`, and
`git pull --ff-only`.

## Required Windows environment

- Windows 11 AMD64/x64 and the signed-in Codex desktop client;
- Git for Windows, .NET 8 SDK, and Visual Studio 2022 or Build Tools with the .NET desktop workload;
- optional GitHub CLI for inspecting Actions and Release assets.

Do not run Codex, PowerShell, or the setup as Administrator. Windows ARM64 is out of scope for the
v0.3.3 package.

## First Codex task

Open the repository root in Codex and use this initial task:

```text
Continue Codex Usage Sidebar Windows maintenance from main. Read docs/releases/v0.3.3.md,
docs/WINDOWS-BETA.md, docs/WINDOWS-DEVICE-HANDOFF.md, and docs/ARCHITECTURE.md. Confirm the
published v0.3.3 release and run the documented .NET build/tests. If investigating a missing
overlay, collect only a sanitized UIA report from a disposable Codex task. Unknown or unsafe UIA
structures must hide the overlay; do not guess coordinates, edit selectors.json manually, or
replace release assets. Record a reproducible diagnostic before changing selectors or installer
behavior.
```

## Baseline commands

```powershell
$ErrorActionPreference = 'Stop'
dotnet restore .\plugins\codex-usage-sidebar\windows\CodexUsageSidebar.Windows.sln
dotnet build .\plugins\codex-usage-sidebar\windows\CodexUsageSidebar.Windows.sln --configuration Release --no-restore --nologo
dotnet test .\plugins\codex-usage-sidebar\windows\CodexUsageSidebar.Windows.sln --configuration Release --no-build --nologo
```

For post-release diagnostics, follow the [Windows device handoff](WINDOWS-DEVICE-HANDOFF.md).
Commit verified source changes to a feature branch, then merge them into `main` only after the
release and compatibility checks pass.
