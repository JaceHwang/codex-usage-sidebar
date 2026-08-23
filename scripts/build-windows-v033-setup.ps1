[CmdletBinding(DefaultParameterSetName = 'Build')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Build')]
    [string] $ValidationEvidence,
    [Parameter(Mandatory = $true, ParameterSetName = 'Build')]
    [string] $OutputDirectory,
    [Parameter(Mandatory = $true, ParameterSetName = 'Build')]
    [string] $CompatibilityPublicKey,
    [Parameter(Mandatory = $true, ParameterSetName = 'Build')]
    [string] $CompatibilityUpdateUri,
    [Parameter(ParameterSetName = 'Plan')]
    [switch] $PlanOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$plan = [ordered]@{
    schemaVersion = 1
    status = 'release-setup-plan'
    version = '0.3.3'
    architecture = 'x64'
    runtimeIdentifier = 'win-x64'
    requiredBranch = 'v0.3.3'
    artifactName = 'codex-usage-sidebar-v0.3.3-windows-x64-setup.exe'
    embeddedPayload = $true
    selectorsSchemaVersion = 2
    compatibilityConfiguration = 'compatibility-update.json'
    requiresCompleteRealDeviceEvidence = $true
    realDeviceValidated = $false
    publishableInstaller = $false
}
if ($PlanOnly) { $plan | ConvertTo-Json -Depth 3; exit 0 }

try {
    $key = [Convert]::FromBase64String($CompatibilityPublicKey)
    $ecdsa = [Security.Cryptography.ECDsa]::Create()
    try {
        $read = 0
        $ecdsa.ImportSubjectPublicKeyInfo($key, [ref] $read)
        if ($read -ne $key.Length -or $ecdsa.KeySize -ne 256) { throw 'not P-256 SPKI' }
    } finally { $ecdsa.Dispose() }
    $uri = [Uri] $CompatibilityUpdateUri
    if (-not $uri.IsAbsoluteUri -or $uri.Scheme -ne 'https') { throw 'not HTTPS' }
} catch {
    throw 'Windows v0.3.3 setup requires a valid P-256 SPKI public key and HTTPS compatibility update URI.'
}

throw 'Windows v0.3.3 formal setup remains gated until Task 6 records real-device validation evidence.'
