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

$plan = & $script -PlanOnly | ConvertFrom-Json

if ($plan.version -ne '0.3.0-beta.1') { throw 'Unexpected device payload version.' }
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
    Set-Content -LiteralPath (Join-Path $fixture '.gitignore') -Value "src/*.props`nsrc/bin/" -Encoding utf8
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
