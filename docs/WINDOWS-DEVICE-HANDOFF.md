# Windows real-device diagnostic handoff

This procedure is for the future Windows validation phase of `v0.3.0-beta.1`. The artifact is a
diagnostic candidate, not an installer. Run it as the signed-in desktop user, not as Administrator,
and do not publish any resulting report or screenshot.

## 1. Prepare a disposable Codex task

1. Use Windows 11 x64 with the current Codex desktop client installed and signed in.
2. Close conversations that contain private material.
3. Create a disposable task containing only non-sensitive placeholder text.
4. Keep the Codex window visible while capturing each state.

The default probe never stores raw UI Automation names or an executable path. It creates a fresh
random HMAC key for each report, records only per-report tokens and text lengths, and discards the
key. Do not use `--include-text` unless a maintainer explicitly requests a second, controlled
capture after the default report proves insufficient.

## 2. Verify the diagnostic candidate

Download the artifact named
`codex-usage-sidebar-v0.3.0-beta.1-windows-x64-diagnostic` from a successful
**Windows beta diagnostic candidate** Actions run. Put the ZIP, checksum, and provenance files in
one directory, then run PowerShell from that directory:

```powershell
$ErrorActionPreference = 'Stop'
$line = Get-Content -LiteralPath .\WINDOWS-BETA-SHA256SUMS.txt
$expected, $archiveName = $line -split '  ', 2
$actual = (Get-FileHash -LiteralPath ".\$archiveName" -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actual -ne $expected) { throw 'Diagnostic ZIP checksum mismatch.' }

$provenance = Get-Content -Raw -LiteralPath .\WINDOWS-BETA-PROVENANCE.json | ConvertFrom-Json
if ($provenance.version -ne '0.3.0-beta.1' -or
    $provenance.architecture -ne 'x64' -or
    $provenance.status -ne 'diagnostic-candidate' -or
    $provenance.realDeviceValidated -ne $false -or
    $provenance.publishableInstaller -ne $false) {
    throw 'Unexpected diagnostic provenance.'
}

Expand-Archive -LiteralPath ".\$archiveName" -DestinationPath .\diagnostic -Force
```

Stop if either verification fails. A diagnostic candidate must never be treated as a setup
program or a usable Windows release.

## 3. Capture the geometry states

Create an output directory and run one default probe for every row below. Use the exact file names
so reports and screenshots remain paired:

```powershell
New-Item -ItemType Directory -Force C:\Temp\codex-usage-sidebar-probes | Out-Null
Set-Location .\diagnostic
.\CodexUsageSidebar.Control.exe probe C:\Temp\codex-usage-sidebar-probes\01-restored-collapsed.json
```

| File prefix | Codex state to capture |
| --- | --- |
| `01-restored-collapsed` | Restored window; left, right, and bottom panes collapsed |
| `02-left-expanded` | Left pane expanded |
| `03-right-expanded` | Right pane expanded at its default width |
| `04-right-wide` | Right pane dragged left until it is wide |
| `05-left-right-expanded` | Left and right panes both expanded |
| `06-bottom-expanded` | Bottom pane expanded |
| `07-narrow-window` | Narrowest practical restored window |
| `08-maximized` | Maximized window |
| `09-fullscreen` | Fullscreen window |
| `10-second-monitor` | Window on another monitor, when available |

For every state, save a matching PNG screenshot using the same prefix. The disposable task must be
visible, and the screenshot must not include notifications, account names, unrelated windows, or
private task titles.

## 4. Capture theme, language, and scaling variants

Repeat `01-restored-collapsed`, `04-right-wide`, and `05-left-right-expanded` for:

- light, dark, and system themes;
- Simplified Chinese, Traditional Chinese, and English;
- 100%, 125%, 150%, and 200% display scaling when the hardware supports them.

Name variants as `<base>-<theme>-<language>-<scale>.json`, for example:

```text
04-right-wide-dark-zh-CN-150.json
```

Restart Codex after changing a setting when the client does not update the visible UI immediately.

## 5. Package the handoff locally

Review the screenshots one last time, then create a local bundle and checksum:

```powershell
$root = 'C:\Temp\codex-usage-sidebar-probes'
$bundle = 'C:\Temp\codex-usage-sidebar-probes.zip'
Compress-Archive -Path "$root\*" -DestinationPath $bundle -Force
Get-FileHash -LiteralPath $bundle -Algorithm SHA256 | Format-List
```

Send the ZIP and its SHA-256 only through the private channel agreed with the maintainer. Keep the
original reports until the maintainer confirms that the bundle opens and the digest matches.

## 6. What happens next

The reports are used to bind semantic UIA selectors and geometry fixtures. The first Windows build
that displays an overlay must then pass placement, hover/pin, focus, DPI, language, theme,
sleep/resume, Codex restart/update, install, repair, and uninstall testing on the same source and
provenance chain. Until that evidence exists, unknown Codex UIA trees must keep the overlay hidden
and no Windows setup asset may be published.
