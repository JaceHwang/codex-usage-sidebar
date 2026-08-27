# Windows v0.3.3 real-device diagnostics handoff

Use this procedure for post-release diagnostics and compatibility reports for the published v0.3.3 Windows setup on a real Windows 11 AMD64/x64 computer. It is not authorization to bypass Windows security UI or publish new assets.

## 1. Prepare safely

Use a signed-in, non-administrator Windows desktop account with Codex open. Create a disposable Codex task containing no private material. Do not capture account data, unrelated windows, real task titles, notifications, or `--include-text` UIA output unless a maintainer explicitly requests a controlled capture.

## 2. Download and verify the exact release

Download `codex-usage-sidebar-v0.3.3-windows-x64-setup.exe`, `WINDOWS-V033-SHA256SUMS.txt`, and `WINDOWS-V033-PROVENANCE.json` from the [v0.3.3 Release](https://github.com/JaceHwang/codex-usage-sidebar/releases/tag/v0.3.3). In PowerShell:

```powershell
$ErrorActionPreference = 'Stop'
$asset = 'codex-usage-sidebar-v0.3.3-windows-x64-setup.exe'
$actual = (Get-FileHash -LiteralPath ".\\$asset" -Algorithm SHA256).Hash.ToLowerInvariant()
$line = Get-Content .\WINDOWS-V033-SHA256SUMS.txt | Where-Object { $_ -match [regex]::Escape($asset) } | Select-Object -First 1
if ([string]::IsNullOrWhiteSpace($line)) { throw 'Checksum entry missing.' }
$expected = ($line -split '\s+', 2)[0].ToLowerInvariant()
if ($actual -ne $expected) { throw "SHA-256 mismatch: $actual" }
$provenance = Get-Content -Raw .\WINDOWS-V033-PROVENANCE.json | ConvertFrom-Json
if ($provenance.version -ne '0.3.3' -or $provenance.architecture -ne 'x64') { throw 'Unexpected v0.3.3 provenance.' }
```

Only after a matching digest may the user choose **More info** then **Run anyway** for the expected unsigned-publisher prompt. Do not disable Defender, SmartScreen, antivirus, or system policy.

## 3. Validate runtime states

Install, then verify `%LOCALAPPDATA%\CodexUsageSidebar\Current` and the current-user `CodexUsageSidebar` Run-key value. Test `--repair` and `--uninstall` only with explicit user authorization. Confirm that installation and removal never modify the official Codex package.

## 4. Capture the visible matrix

For each row, record a sanitized status/probe result and a cropped titlebar screenshot from the disposable task:

| Group | Required states |
| --- | --- |
| Pane/window | collapsed and expanded left/right/bottom panes; narrow, restored, maximized, fullscreen |
| Visual | light, dark, system; 100%, 125%, 150%, 200% DPI when available |
| Language | Simplified Chinese, Traditional Chinese, English, one unsupported locale |
| Interaction | hover, click-to-pin, second-click dismissal, non-activation, insufficient-space fallback |
| Lifecycle | Codex restart/update, sleep/resume, app-server recovery, repair, uninstall |

Unknown or incomplete UIA structures must leave the overlay hidden; never approve a coordinate guess. Send the resulting sanitized bundle and SHA-256 through the agreed private channel only.
