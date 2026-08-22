$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$script = Join-Path $repoRoot 'scripts\install-windows-device-payload.ps1'
$commandLineModule = Join-Path $repoRoot 'plugins\codex-usage-sidebar\scripts\WindowsProcessCommandLine.psm1'
Import-Module $commandLineModule -Force

if (-not ('WindowsCommandLineTest.NativeMethods' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace WindowsCommandLineTest
{
    public static class NativeMethods
    {
        [DllImport("shell32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        private static extern IntPtr CommandLineToArgvW(string commandLine, out int argumentCount);

        [DllImport("kernel32.dll")]
        private static extern IntPtr LocalFree(IntPtr memory);

        public static string[] Parse(string commandLine)
        {
            int count;
            var pointer = CommandLineToArgvW(commandLine, out count);
            if (pointer == IntPtr.Zero) throw new InvalidOperationException("CommandLineToArgvW failed.");
            try
            {
                var result = new string[count];
                for (var index = 0; index < count; index++)
                {
                    result[index] = Marshal.PtrToStringUni(Marshal.ReadIntPtr(pointer, index * IntPtr.Size));
                }
                return result;
            }
            finally
            {
                LocalFree(pointer);
            }
        }
    }
}
'@
}
$commandLineArguments = @(
    '--background',
    '--plugin-root',
    'C:\Users\Device Test\plugin\',
    '--plugin-data',
    'C:\data\with"quote\last\',
    ''
)
$parsedCommandLine = [WindowsCommandLineTest.NativeMethods]::Parse(
    'device-test.exe ' + (Join-WindowsProcessArguments -Arguments $commandLineArguments))
if ($parsedCommandLine.Count -ne ($commandLineArguments.Count + 1)) {
    throw 'The Windows process command line did not preserve the argument count.'
}
for ($index = 0; $index -lt $commandLineArguments.Count; $index++) {
    if ($parsedCommandLine[$index + 1] -cne $commandLineArguments[$index]) {
        throw "The Windows process command line changed argument $index."
    }
}
$processStopwatch = [Diagnostics.Stopwatch]::StartNew()
$deviceProcessExitCode = Invoke-WindowsProcessAndWait `
    -FileName 'powershell.exe' `
    -Arguments @('-NoProfile', '-NonInteractive', '-Command', 'Start-Sleep -Milliseconds 200; exit 23')
if ($deviceProcessExitCode -ne 23 -or $processStopwatch.ElapsedMilliseconds -lt 150) {
    throw 'The Windows device process runner did not wait for and propagate the child exit code.'
}

$plan = & $script -PlanOnly | ConvertFrom-Json

if ($plan.version -ne '0.3.1') { throw 'Unexpected device payload version.' }
$installScript = Get-Content -LiteralPath $script -Raw
if (-not $installScript.Contains('runtime=running pid=\d+ version=0\.3\.1')) {
    throw 'The device installer startup gate must validate the current runtime version.'
}
if ($plan.architecture -ne 'x64' -or $plan.runtimeIdentifier -ne 'win-x64') {
    throw 'The device payload must target Windows AMD64/x64 only.'
}
if ($plan.minimumWindowsBuild -ne 22000) { throw 'The device payload must require Windows 11.' }
if ($plan.hostControlSingleFile -ne $false) {
    throw 'UI Automation capable Host/Control payloads must use a multi-file self-contained publish.'
}
if ($plan.codexRuntime.source -ne 'https://github.com/openai/codex/releases/download/rust-v0.147.0/codex-x86_64-pc-windows-msvc.exe') {
    throw 'The Codex runtime source is not the pinned official x64 release asset.'
}
if ($plan.codexRuntime.sha256 -ne '935a1911ed2556e4ffcec995f4886ac2ac425863ba26fed264df62e30272ad9d') {
    throw 'The pinned Codex runtime digest changed.'
}
if ($plan.status -ne 'device-test' -or
    $plan.realDeviceValidated -ne $false -or
    $plan.publishableInstaller -ne $false) {
    throw 'The device payload must remain explicitly nonpublishable.'
}
if ($plan.installTarget -ne (Join-Path $env:LOCALAPPDATA 'CodexUsageSidebar\Current')) {
    throw 'The device payload target is not the exact current-user install directory.'
}
if ($plan.artifactName -match 'setup|release') {
    throw 'The device payload must not emit a setup or release artifact.'
}

$sourceGateModule = Join-Path $repoRoot 'scripts\WindowsDevicePayload.Source.psm1'
Import-Module $sourceGateModule -Force
$wideFixturePath = Join-Path $repoRoot 'plugins\codex-usage-sidebar\contracts\uia\windows-codex-151.0.7922.76-default-200.json'
$flatFixturePath = Join-Path $repoRoot 'plugins\codex-usage-sidebar\contracts\uia\windows-codex-151.0.7922.76-default-flat-200.json'
$narrowFixturePath = Join-Path $repoRoot 'plugins\codex-usage-sidebar\contracts\uia\windows-codex-151.0.7922.76-narrow-200.json'
$selectors = New-WindowsDeviceSelectorsDocument -FixturePaths @($wideFixturePath, $flatFixturePath, $narrowFixturePath)
if ($selectors.schemaVersion -ne 1 -or
    $selectors.status -ne 'device-test' -or
    $selectors.realDeviceValidated -ne $false -or
    $selectors.publishableInstaller -ne $false) {
    throw 'The selector payload must remain explicitly nonpublishable.'
}
if ($selectors.builds.Count -ne 3) {
    throw 'The selector payload must include wrapped-wide, flat-wide, and narrow real-device fixtures.'
}
$wideSelector = @($selectors.builds | Where-Object { $_.layout -eq 'wide' })
$flatSelector = @($selectors.builds | Where-Object { $_.layout -eq 'wide-flat' })
$narrowSelector = @($selectors.builds | Where-Object { $_.layout -eq 'narrow' })
if ($wideSelector.Count -ne 1 -or
    $wideSelector[0].fixture -ne 'windows-codex-151.0.7922.76-default-200.json' -or
    $wideSelector[0].sourceReportSha256 -ne '91974840970bde79b21760aac92fd35b85a7d872058fdf04cd05d824c4f14632') {
    throw 'The wide selector fixture provenance is not pinned.'
}
if ($flatSelector.Count -ne 1 -or
    $flatSelector[0].fixture -ne 'windows-codex-151.0.7922.76-default-flat-200.json' -or
    $flatSelector[0].sourceReportSha256 -ne '385871394861f49437b7b8e5e446d4d5c1eaf14b2d41a70adea6d68647c5d840') {
    throw 'The flat wide selector fixture provenance is not pinned.'
}
if ($narrowSelector.Count -ne 1 -or
    $narrowSelector[0].fixture -ne 'windows-codex-151.0.7922.76-narrow-200.json' -or
    $narrowSelector[0].sourceReportSha256 -ne 'a6e78da5d5cfbc8c2f34b85c85e8bf59c1cbde18ca9c02928b25a321a99f0a53') {
    throw 'The narrow selector fixture provenance is not pinned.'
}
Assert-WindowsDevicePlatform -IsWindows $true -Architecture 'x64' -WindowsBuild 22000
Assert-WindowsDevicePlatform -IsWindows $true -Architecture 'x64' -WindowsBuild 26200
try {
    Assert-WindowsDevicePlatform -IsWindows $true -Architecture 'arm64' -WindowsBuild 26200
    throw 'ARM64 unexpectedly passed the device platform gate.'
}
catch [PlatformNotSupportedException] {
}
try {
    Assert-WindowsDevicePlatform -IsWindows $true -Architecture 'x64' -WindowsBuild 19045
    throw 'Windows 10 unexpectedly passed the device platform gate.'
}
catch [PlatformNotSupportedException] {
}
$attempts = 0
$conditionResult = Wait-WindowsDeviceCondition -TimeoutMilliseconds 1000 -PollMilliseconds 1 -Condition {
    $script:attempts++
    if ($script:attempts -ge 3) { return 'running' }
    return $null
}
if ($conditionResult -ne 'running' -or $attempts -ne 3) {
    throw 'The device condition wait did not return the first successful observation.'
}
try {
    Wait-WindowsDeviceCondition -TimeoutMilliseconds 5 -PollMilliseconds 1 -Condition { $null } | Out-Null
    throw 'A device condition timeout unexpectedly succeeded.'
}
catch [TimeoutException] {
}
$runtimeCacheFixture = Join-Path ([IO.Path]::GetTempPath()) ('cus-runtime-cache-' + [Guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Force -Path $runtimeCacheFixture | Out-Null
    $installLockPath = Join-Path $runtimeCacheFixture 'install.lock'
    $installLock = Enter-WindowsDeviceInstallLock -LockPath $installLockPath
    try {
        if (-not (Test-WindowsSidebarInstallInProgress -LockPath $installLockPath)) {
            throw 'The sidebar control did not detect the active device installation lock.'
        }
    }
    finally {
        $installLock.Dispose()
    }
    if (Test-WindowsSidebarInstallInProgress -LockPath $installLockPath) {
        throw 'The sidebar control treated a released device installation lock as active.'
    }
    $badRuntime = Join-Path $runtimeCacheFixture 'bad.exe'
    $goodRuntime = Join-Path $runtimeCacheFixture 'good.exe'
    $cachedRuntime = Join-Path $runtimeCacheFixture 'copied.exe'
    [IO.File]::WriteAllBytes($badRuntime, [byte[]](1, 2, 3))
    [IO.File]::WriteAllBytes($goodRuntime, [byte[]](4, 5, 6, 7))
    $goodRuntimeSha256 = (Get-FileHash -LiteralPath $goodRuntime -Algorithm SHA256).Hash.ToLowerInvariant()
    if (-not (Copy-WindowsDeviceRuntimeFromCache `
        -Candidates @($badRuntime, $goodRuntime) `
        -Destination $cachedRuntime `
        -ExpectedSha256 $goodRuntimeSha256)) {
        throw 'A digest-matching device runtime cache entry was not reused.'
    }
    if ((Get-FileHash -LiteralPath $cachedRuntime -Algorithm SHA256).Hash.ToLowerInvariant() -ne $goodRuntimeSha256) {
        throw 'The reused device runtime did not preserve the pinned digest.'
    }
    Remove-Item -LiteralPath $cachedRuntime
    if (Copy-WindowsDeviceRuntimeFromCache `
        -Candidates @($badRuntime) `
        -Destination $cachedRuntime `
        -ExpectedSha256 $goodRuntimeSha256) {
        throw 'A mismatched device runtime cache entry was reused.'
    }
}
finally {
    $expectedParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar)
    if ((Split-Path -Parent ([IO.Path]::GetFullPath($runtimeCacheFixture))).TrimEnd([IO.Path]::DirectorySeparatorChar) -ne $expectedParent -or
        -not (Split-Path -Leaf $runtimeCacheFixture).StartsWith('cus-runtime-cache-', [StringComparison]::Ordinal)) {
        throw 'Refusing to clean an unexpected runtime-cache fixture path.'
    }
    if (Test-Path -LiteralPath $runtimeCacheFixture) { Remove-Item -LiteralPath $runtimeCacheFixture -Recurse -Force }
}
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('cus-source-gate-' + [Guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Force -Path (Join-Path $fixture 'src\bin') | Out-Null
    Set-Content -LiteralPath (Join-Path $fixture '.gitignore') -Value "src/*.props`nsrc/bin/`n.superpowers/sdd/`n.superpowers/other/" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $fixture 'src\app.cs') -Value 'sealed class App {}' -Encoding utf8
    & git -C $fixture init --quiet
    & git -C $fixture config user.email 'device-test@example.invalid'
    & git -C $fixture config user.name 'Device Test'
    & git -C $fixture add .
    & git -C $fixture commit --quiet -m baseline
    $commit = Assert-WindowsDeviceSourceState -RepositoryRoot $fixture -BuildInputRoots @('.')
    if ($commit -notmatch '^[0-9a-f]{40}$') { throw 'Clean source gate did not return a commit.' }

    Set-Content -LiteralPath (Join-Path $fixture 'src\untracked.cs') -Value 'sealed class Untracked {}' -Encoding utf8
    try {
        Assert-WindowsDeviceSourceState -RepositoryRoot $fixture -BuildInputRoots @('.') | Out-Null
        throw 'Untracked source unexpectedly passed the provenance gate.'
    }
    catch [InvalidOperationException] {
    }
    Remove-Item -LiteralPath (Join-Path $fixture 'src\untracked.cs')

    Set-Content -LiteralPath (Join-Path $fixture 'src\app.cs') -Value 'sealed class Changed {}' -Encoding utf8
    try {
        Assert-WindowsDeviceSourceState -RepositoryRoot $fixture -BuildInputRoots @('.') | Out-Null
        throw 'Tracked source change unexpectedly passed the provenance gate.'
    }
    catch [InvalidOperationException] {
    }
    Set-Content -LiteralPath (Join-Path $fixture 'src\app.cs') -Value 'sealed class App {}' -Encoding utf8

    Set-Content -LiteralPath (Join-Path $fixture 'src\Directory.Build.props') -Value '<Project />' -Encoding utf8
    try {
        Assert-WindowsDeviceSourceState -RepositoryRoot $fixture -BuildInputRoots @('.') | Out-Null
        throw 'Ignored build input unexpectedly passed the provenance gate.'
    }
    catch [InvalidOperationException] {
    }
    Remove-Item -LiteralPath (Join-Path $fixture 'src\Directory.Build.props')
    Set-Content -LiteralPath (Join-Path $fixture 'src\bin\generated.cs') -Value 'excluded' -Encoding utf8
    Assert-WindowsDeviceSourceState -RepositoryRoot $fixture -BuildInputRoots @('.') | Out-Null

    $taskLedgerPath = Join-Path $fixture '.superpowers\sdd\progress.md'
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $taskLedgerPath) | Out-Null
    Set-Content -LiteralPath $taskLedgerPath -Value 'private task ledger metadata' -Encoding utf8
    Assert-WindowsDeviceSourceState -RepositoryRoot $fixture -BuildInputRoots @('.') | Out-Null

    $otherSuperpowersPath = Join-Path $fixture '.superpowers\other\input.txt'
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $otherSuperpowersPath) | Out-Null
    Set-Content -LiteralPath $otherSuperpowersPath -Value 'unsafe ignored input' -Encoding utf8
    try {
        Assert-WindowsDeviceSourceState -RepositoryRoot $fixture -BuildInputRoots @('.') | Out-Null
        throw 'Ignored non-SDD Superpowers input unexpectedly passed the provenance gate.'
    }
    catch [InvalidOperationException] {
    }
}
finally {
    $expectedParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar)
    if ((Split-Path -Parent ([IO.Path]::GetFullPath($fixture))).TrimEnd([IO.Path]::DirectorySeparatorChar) -ne $expectedParent -or
        -not (Split-Path -Leaf $fixture).StartsWith('cus-source-gate-', [StringComparison]::Ordinal)) {
        throw 'Refusing to clean an unexpected source-gate fixture path.'
    }
    if (Test-Path -LiteralPath $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
}

Write-Output 'PASS: Windows x64 device payload plan is pinned and nonpublishable'
