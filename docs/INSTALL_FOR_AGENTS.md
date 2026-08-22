# Install with an Agent

This playbook is for a coding agent with terminal access to the target computer. Use the Windows
path for the public `v0.3.1` setup once its real-device gate is published, and the macOS path for the stable v0.2.3 marketplace/DMG
installation.

## Windows 11 AMD64/x64 automatic setup install

### Copy-paste task

```text
Install Codex Usage Sidebar v0.3.1 from the GitHub Release on this Windows 11 AMD64/x64 machine.

Requirements:
1. Confirm this is Windows 11 on AMD64/x64. Windows ARM64 is unsupported.
2. Download only codex-usage-sidebar-v0.3.1-windows-x64-setup.exe and WINDOWS-V031-SHA256SUMS.txt
   from https://github.com/JaceHwang/codex-usage-sidebar/releases/tag/v0.3.1.
   Setup URL: https://github.com/JaceHwang/codex-usage-sidebar/releases/download/v0.3.1/codex-usage-sidebar-v0.3.1-windows-x64-setup.exe.
3. Verify the setup SHA-256 matches the corresponding entry in WINDOWS-V031-SHA256SUMS.txt.
4. Run the setup only if the digest matches.
5. Do not disable or bypass Defender, SmartScreen, antivirus, or system policy.
6. If installer, SmartScreen, uninstall, or Windows security UI appears, stop and ask me for
   immediate confirmation before clicking it.
7. Report the install path, Run-key autostart state, runtime status, and whether Codex shows the
   overlay near its supported titlebar anchor. Do not expose unrelated windows, conversations, or
   account data.
8. Do not claim the setup lifecycle was locally validated unless the install, launch, repair or
   uninstall step you are reporting actually completed on this machine.
```

### Deterministic procedure

#### 1. Preflight

```powershell
$ErrorActionPreference = 'Stop'
[System.Environment]::OSVersion.Version
(Get-CimInstance Win32_OperatingSystem).Caption
$env:PROCESSOR_ARCHITECTURE
```

Proceed only on Windows 11 AMD64/x64. Report a failed requirement instead of attempting an
unsupported installation.

#### 2. Download

```powershell
$ErrorActionPreference = 'Stop'
$release = 'https://github.com/JaceHwang/codex-usage-sidebar/releases/download/v0.3.1'
$asset = 'codex-usage-sidebar-v0.3.1-windows-x64-setup.exe'
$checksum = 'WINDOWS-V031-SHA256SUMS.txt'
$dest = Join-Path $env:TEMP 'codex-usage-sidebar-v0.3.1'
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Invoke-WebRequest "$release/$asset" -OutFile (Join-Path $dest $asset)
Invoke-WebRequest "$release/$checksum" -OutFile (Join-Path $dest $checksum)
```

#### 3. Verify SHA-256

```powershell
$setup = Join-Path $dest $asset
$actual = (Get-FileHash $setup -Algorithm SHA256).Hash.ToLowerInvariant()
$checksumText = Get-Content -Raw (Join-Path $dest $checksum)
$checksumLine = $checksumText -split "`r?`n" | Where-Object { $_ -match [regex]::Escape($asset) } | Select-Object -First 1
if ([string]::IsNullOrWhiteSpace($checksumLine)) { throw 'Checksum file has no entry for the setup asset.' }
$expected = ($checksumLine -split '\s+', 2)[0].ToLowerInvariant()
if ($actual -ne $expected) { throw "SHA-256 mismatch: $actual" }
if ($checksumText.ToLowerInvariant() -notmatch [regex]::Escape($expected)) {
  throw 'Checksum file does not contain the expected setup digest.'
}
```

Never run the setup after a digest mismatch. Delete the files and download them again from the
release.

#### 4. Run setup

```powershell
Start-Process -FilePath $setup -Wait
```

The setup is intentionally unsigned (`NotSigned`), so Windows may show **Unknown publisher**. After
confirming the SHA-256 match, the user may choose **More info** and **Run anyway**. The agent must
not click installer, SmartScreen, uninstall, or Windows security UI without immediate user
confirmation, and must not disable Defender, SmartScreen, antivirus, or system policy.

#### 5. Verify runtime

```powershell
$installRoot = Join-Path $env:LOCALAPPDATA 'CodexUsageSidebar\Current'
Test-Path $installRoot
Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' |
  Select-Object -Property CodexUsageSidebar
Get-ChildItem $installRoot -ErrorAction Stop | Select-Object -First 10 Name
```

If a project control script or installed status command is available on the target machine, prefer
that status output over inferred process names. Interpret Windows status conservatively:

- `runtime=unavailable` means no approved runtime is available.
- `runtime=stopped` means the installed runtime is present but not running.
- `runtime=running` means the approved runtime is active.
- Unknown or unsupported UI Automation structures hide the overlay; do not guess coordinates.
- The `v0.3.1` package has automated gates and still requires the real-device matrix. Do not claim
  full 130-case or setup lifecycle validation unless you performed it on that machine.

#### 6. Repair or uninstall when explicitly requested

Only run these after verifying the same setup bytes and receiving user approval for the requested
action:

```powershell
Start-Process -FilePath $setup -ArgumentList '--repair' -Wait
Start-Process -FilePath $setup -ArgumentList '--uninstall' -Wait
```

Uninstall does not modify the official Codex installation and does not require administrator
privileges.

#### 7. Report evidence

Return the release tag, setup SHA-256, install root, Run-key autostart state, runtime status,
SmartScreen/Unknown publisher handling, and any visible overlay result. If the overlay is absent,
state whether runtime status or unsupported UIA structure is the likely reason; do not infer private
conversation content or hidden coordinates.

## macOS 14+ Apple Silicon agent install

This path is for a coding agent with terminal access to the target Mac.

### Copy-paste task

```text
Install Codex Usage Sidebar from the public GitHub marketplace.

Requirements:
1. Verify macOS 14+, Apple Silicon, Codex desktop, and the codex CLI.
2. Install JaceHwang/codex-usage-sidebar through the codex plugin marketplace commands.
3. Do not modify, inject into, or re-sign the official Codex application.
4. Explain that a new Codex task is required before the SessionStart hook is available.
5. Authorize the companion's isolated CodexHome with the official codex login command.
6. In the new task, invoke @codex-usage-sidebar to check and repair the installation.
7. Verify the LaunchAgent, status output, isolated login, and accessibility state.
8. If Accessibility is off, open the correct System Settings pane and ask me to approve the switch.
9. Resize the right pane and confirm collision-free adaptive placement: a resolved local source
   keeps an 8-point edge gap, while insufficient space selects the safe right-side fallback. Do not
   expose unrelated windows, conversations, or account data.
```

### Deterministic procedure

#### 1. Preflight

```bash
test "$(uname -s)" = Darwin
test "$(uname -m)" = arm64
sw_vers -productVersion
codex --version
codex plugin --help
```

Report a failed requirement instead of attempting an unsupported installation.

#### 2. Install

```bash
codex plugin marketplace add JaceHwang/codex-usage-sidebar
codex plugin add codex-usage-sidebar@codex-usage-sidebar
codex plugin list
```

Confirm `codex-usage-sidebar@codex-usage-sidebar` is installed and enabled.

#### 3. Cross the task boundary

Plugins and skills load when a task starts. Ask the user to create a new Codex task, then invoke:

```text
@codex-usage-sidebar check the installation and repair it if needed
```

#### 4. Authorize the isolated Codex home

```bash
plugin_home="$HOME/Library/Application Support/CodexUsageSidebar/CodexHome"
env CODEX_HOME="$plugin_home" codex login
env CODEX_HOME="$plugin_home" codex login status
```

The login flow is interactive and may require the user to finish authorization. Do not copy
`~/.codex/auth.json` into the isolated home.

#### 5. Verify runtime and placement

```bash
control="$HOME/Library/Application Support/CodexUsageSidebar/sidebar-control.sh"
test -x "$control"
"$control" status
launchctl print "gui/$(id -u)/com.jace.codex-usage-sidebar"
```

Interpret status conservatively:

- `installed and loaded` confirms the managed runtime is present.
- `accessibility=granted` permits semantic placement checks.
- `accessibility=required` means the user must approve the macOS switch.
- `placement=content-header` with `openLocation`, `labeledControl`, or `rightPaneBoundary` confirms
  a resolved collision-free local placement.
- `fallback` with a numeric edge confirms the intentional safe right-side placement used when no
  complete local slot remains; it is not a failure.
- `cached:false` is the expected v0.2.3 steady state because every 0.1-second tick re-scans eligible
  titlebar geometry for collisions.
- `pid=<LaunchAgent PID>` confirms status came from the managed process rather than a standalone
  diagnostic invocation.
- `version=<version>` must match the visible badge beside the hover-card title.
- For a resolved non-fallback source with `indicator=x,y,width,height` and `edge=n`, `x + width`
  must equal `n - 8`.

Accessibility is a macOS security permission. Never bypass it or claim it is granted before the OS
reports that state.

#### 6. Repair after an update

```bash
"$HOME/Library/Application Support/CodexUsageSidebar/sidebar-control.sh" repair
```

The companion rediscovers the current Codex bundle and its `app-server`; no official application
patch is required. Repair also verifies the source fingerprint, atomically replaces stale payloads,
and preserves the stable local signing identity when available.

#### 7. Report evidence

Return the plugin version, login status, companion status, LaunchAgent state, Accessibility state,
anchor source, and whether the control avoids native controls while the right pane is dragged
through intermediate widths. Confirm both the nearest-free-slot and safe-right-fallback states.
Crop screenshots to the relevant titlebar area.
