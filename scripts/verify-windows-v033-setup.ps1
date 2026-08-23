[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string] $CandidateDirectory,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-f]{40}$')][string] $SourceCommit,
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-f]{40}$')][string] $PackagingCommit
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not [Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([Runtime.InteropServices.OSPlatform]::Windows) -or [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString() -ne 'X64' -or [Environment]::OSVersion.Version.Build -lt 22000) {
    throw 'Windows v0.3.3 setup verification requires Windows 11 AMD64/x64.'
}
$root = (Resolve-Path -LiteralPath $CandidateDirectory).Path
if ((Get-Item -LiteralPath $root).Attributes.HasFlag([IO.FileAttributes]::ReparsePoint)) { throw 'The Windows setup candidate directory cannot be a link or reparse point.' }
$artifactName = 'codex-usage-sidebar-v0.3.3-windows-x64-setup.exe'
$setup = Join-Path $root $artifactName
$provenancePath = Join-Path $root 'WINDOWS-V033-PROVENANCE.json'
$checksumsPath = Join-Path $root 'WINDOWS-V033-SHA256SUMS.txt'
foreach ($required in @($setup, $provenancePath, $checksumsPath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "The Windows setup candidate is missing: $required" }
    if ((Get-Item -LiteralPath $required).Attributes.HasFlag([IO.FileAttributes]::ReparsePoint)) { throw "The Windows setup candidate file cannot be a link or reparse point: $required" }
}
$checksumLine = (Get-Content -Raw -LiteralPath $checksumsPath).Trim()
$escapedArtifact = [Regex]::Escape($artifactName)
if ($checksumLine -notmatch "^([0-9a-f]{64})  $escapedArtifact$") { throw 'The Windows setup checksum file has an invalid shape.' }
$actualSha256 = (Get-FileHash -LiteralPath $setup -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualSha256 -ne $Matches[1]) { throw 'The Windows setup SHA-256 does not match its checksum file.' }
$provenance = Get-Content -Raw -LiteralPath $provenancePath | ConvertFrom-Json
$expectedSource = 'https://github.com/openai/codex/releases/download/rust-v0.147.0/codex-x86_64-pc-windows-msvc.exe'
$expectedDigest = '935a1911ed2556e4ffcec995f4886ac2ac425863ba26fed264df62e30272ad9d'
if ($provenance.schemaVersion -ne 1 -or $provenance.status -ne 'release-candidate' -or $provenance.version -ne '0.3.3' -or $provenance.architecture -ne 'x64' -or $provenance.runtimeIdentifier -ne 'win-x64' -or $provenance.sourceCommit -ne $SourceCommit -or $provenance.validatedSourceCommit -ne $SourceCommit -or $provenance.packagingCommit -ne $PackagingCommit -or $provenance.artifact -ne $artifactName -or $provenance.sha256 -ne $actualSha256 -or $provenance.realDeviceValidated -isnot [bool] -or -not $provenance.realDeviceValidated -or $provenance.publishableInstaller -isnot [bool] -or -not $provenance.publishableInstaller -or $provenance.codexRuntime.source -ne $expectedSource -or $provenance.codexRuntime.sha256 -ne $expectedDigest -or $provenance.payloadManifestSha256 -notmatch '^[0-9a-f]{64}$' -or $provenance.validationEvidenceSha256 -notmatch '^[0-9a-f]{64}$' -or $provenance.compatibilityConfigurationSha256 -notmatch '^[0-9a-f]{64}$') {
    throw 'The Windows v0.3.3 setup provenance is incomplete or does not match this candidate.'
}
$authenticode = Get-AuthenticodeSignature -LiteralPath $setup
$actualSigner = if ($null -ne $authenticode.SignerCertificate) { $authenticode.SignerCertificate.Subject } else { $null }
if ($provenance.authenticodeStatus -ne $authenticode.Status.ToString() -or $provenance.signerSubject -ne $actualSigner) { throw 'The Windows setup Authenticode state does not match its provenance.' }
$repoRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $repoRoot 'plugins\codex-usage-sidebar\scripts\WindowsProcessCommandLine.psm1') -Force
if ((Invoke-WindowsProcessAndWait -FileName $setup -Arguments @('--verify-embedded')) -ne 0) { throw 'The Windows v0.3.3 setup embedded payload verification failed.' }
Write-Output "PASS: Windows v0.3.3 x64 setup candidate $actualSha256 from $SourceCommit"
