$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$script = Join-Path $repoRoot 'scripts\install-windows-device-payload.ps1'
$plan = & $script -PlanOnly | ConvertFrom-Json

if ($plan.version -ne '0.3.0-beta.1') { throw 'Unexpected device payload version.' }
if ($plan.architecture -ne 'x64' -or $plan.runtimeIdentifier -ne 'win-x64') {
    throw 'The device payload must target Windows AMD64/x64 only.'
}
if ($plan.minimumWindowsBuild -ne 22000) { throw 'The device payload must require Windows 11.' }
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
