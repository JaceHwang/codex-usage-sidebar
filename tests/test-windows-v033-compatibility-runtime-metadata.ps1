[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path $repoRoot 'scripts\WindowsDevicePayload.Source.psm1'
Import-Module $modulePath -Force

$v032Fixtures = @(
    'windows-codex-151.0.7922.76-default-200.json',
    'windows-codex-151.0.7922.76-default-flat-200.json',
    'windows-codex-151.0.7922.76-narrow-200.json'
) | ForEach-Object { Join-Path $repoRoot ('plugins\codex-usage-sidebar\contracts\uia\' + $_) }
$v032Selectors = New-WindowsDeviceSelectorsDocument -FixturePaths $v032Fixtures
if ($v032Selectors.schemaVersion -ne 1 -or
    $v032Selectors.status -cne 'device-test' -or
    $v032Selectors.realDeviceValidated -ne $false -or
    $v032Selectors.publishableInstaller -ne $false -or
    $v032Selectors.builds.Count -ne 3 -or
    ($v032Selectors.builds.layout -join ',') -cne 'wide-flat,wide,narrow' -or
    (@($v032Selectors.builds.buildIdentity | Select-Object -Unique) -join ',') -cne '151.0.7922.76') {
    throw 'The shared payload module changed the v0.3.2 selector manifest contract.'
}

if ($null -eq (Get-Command -Name New-WindowsV033HostControlPublishProperties -ErrorAction SilentlyContinue)) {
    throw 'The v0.3.3 Host/Control publish property contract is missing.'
}

$compatibilityPublicKey = 'MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEGhz+XZxUarxEbLW+RiAf4QtCMvX5rIUA+6yTie9NyM+8erFgK6sbNKalTzTwCu4MLpVI6fqW2CAQ5Y8t/oi7ig=='
$compatibilityUpdateUri = 'https://example.invalid/pack.zip'
$output = Join-Path ([IO.Path]::GetTempPath()) ('cus-v033-runtime-metadata-' + [Guid]::NewGuid().ToString('N'))
try {
    $properties = New-WindowsV033HostControlPublishProperties `
        -Framework 'net8.0-windows10.0.19041.0' `
        -RuntimeIdentifier 'win-x64' `
        -SourceCommit '0123456789abcdef0123456789abcdef01234567' `
        -CompatibilityPublicKey $compatibilityPublicKey `
        -CompatibilityUpdateUri $compatibilityUpdateUri
    $controlProject = Join-Path $repoRoot 'plugins\codex-usage-sidebar\windows\src\CodexUsageSidebar.Control\CodexUsageSidebar.Control.csproj'
    & dotnet publish $controlProject @properties '-p:PublishSingleFile=false' --output $output
    if ($LASTEXITCODE -ne 0) { throw 'The v0.3.3 Host/Control metadata integration publish failed.' }

$inspection = @'
$ErrorActionPreference = 'Stop'
$assembly = [Reflection.Assembly]::LoadFrom($env:CUS_V033_HOST_ASSEMBLY)
$metadata = @{}
foreach ($attribute in $assembly.GetCustomAttributes($true) | Where-Object { $_ -is [Reflection.AssemblyMetadataAttribute] }) {
    $metadata[$attribute.Key] = $attribute.Value
}
$metadata | ConvertTo-Json -Compress
'@
    $env:CUS_V033_HOST_ASSEMBLY = Join-Path $output 'CodexUsageSidebar.Windows.dll'
    try {
        $metadataJson = & pwsh -NoProfile -Command $inspection
        if ($LASTEXITCODE -ne 0) { throw 'The v0.3.3 Host metadata inspection process failed.' }
    }
    finally {
        Remove-Item Env:\CUS_V033_HOST_ASSEMBLY -ErrorAction SilentlyContinue
    }
    $metadataByKey = $metadataJson | ConvertFrom-Json -AsHashtable
    if ($metadataByKey['CompatibilityPublicKey'] -cne $compatibilityPublicKey -or
        $metadataByKey['CompatibilityUpdateUri'] -cne $compatibilityUpdateUri) {
        throw 'The published v0.3.3 Host assembly does not contain the validated compatibility metadata.'
    }
    Write-Output 'PASS: Windows v0.3.3 Host runtime compatibility metadata is published.'
}
finally {
    if (Test-Path -LiteralPath $output) { Remove-Item -LiteralPath $output -Recurse -Force }
}
