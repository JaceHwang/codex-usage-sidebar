$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$modulePath = Join-Path $PSScriptRoot '..\scripts\WindowsDevicePayload.Source.psm1'
Import-Module $modulePath -Force

$fixtureRoot = Join-Path $PSScriptRoot '..\plugins\codex-usage-sidebar\contracts\uia'
$fixtures = @(
    (Join-Path $fixtureRoot 'windows-codex-151.0.7922.76-default-200.json'),
    (Join-Path $fixtureRoot 'windows-codex-151.0.7922.76-default-flat-200.json'),
    (Join-Path $fixtureRoot 'windows-codex-151.0.7922.76-narrow-200.json')
)
$catalog = New-WindowsV033SelectorsDocument -FixturePaths $fixtures
if ($catalog.schemaVersion -ne 2 -or $catalog.profiles.Count -ne 1) {
    throw 'The v0.3.3 selector catalog must use schema-v2 profiles.'
}
$profile = $catalog.profiles[0]
if ($profile.buildIdentities.Count -ne 1 -or
    $profile.buildIdentities[0] -cne '151.0.7922.76' -or
    $null -eq $profile.markerAliases -or
    $profile.maxWrapperDepth -ne 2 -or
    $profile.depthTolerance -ne 2) {
    throw 'The v0.3.3 selector profile does not bind the validated Codex fixture family.'
}

Write-Output 'PASS: v0.3.3 selector builder emits a schema-v2 catalog'
