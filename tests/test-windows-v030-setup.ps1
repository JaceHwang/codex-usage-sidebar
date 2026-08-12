$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$script = Join-Path $repoRoot 'scripts\build-windows-v030-setup.ps1'
$verifier = Join-Path $repoRoot 'scripts\verify-windows-v030-setup.ps1'
$plan = (& $script -PlanOnly | Out-String) | ConvertFrom-Json
if ($plan.version -ne '0.3.0' -or
    $plan.architecture -ne 'x64' -or
    $plan.runtimeIdentifier -ne 'win-x64' -or
    $plan.requiredBranch -ne 'v0.3.0' -or
    $plan.artifactName -ne 'codex-usage-sidebar-v0.3.0-windows-x64-setup.exe' -or
    $plan.requiresCompleteRealDeviceEvidence -ne $true) {
    throw 'The Windows v0.3.0 setup plan is incomplete or has the wrong architecture.'
}

$content = Get-Content -Raw -LiteralPath $script
foreach ($required in @(
    'verify-windows-v030-validation.py',
    'verify-v030-packaging-delta.py',
    'build-windows-v030-release-manifest.py',
    'verify-windows-v030-release-payload.py',
    '--verify-embedded',
    'InstallerPayloadMode=embedded-release',
    'validatedSourceCommit',
    'packagingCommit',
    'status --porcelain=v1 --untracked-files=all',
    "'v0.3.0'"
)) {
    if (-not $content.Contains($required)) {
        throw "The Windows setup builder is missing a required release gate: $required"
    }
}
if ($content -match '(?i)win-arm64|windows-arm64') {
    throw 'Windows ARM64 must not be a v0.3.0 setup build target.'
}
if ($content -match '(?i)gh release|softprops/action-gh-release') {
    throw 'The local Windows setup builder must not publish GitHub releases.'
}

$verifierContent = Get-Content -Raw -LiteralPath $verifier
foreach ($required in @(
    'codex-usage-sidebar-v0.3.0-windows-x64-setup.exe',
    'WINDOWS-V030-PROVENANCE.json',
    'WINDOWS-V030-SHA256SUMS.txt',
    '--verify-embedded',
    'Get-AuthenticodeSignature'
)) {
    if (-not $verifierContent.Contains($required)) {
        throw "The Windows setup verifier is missing a required check: $required"
    }
}

Write-Output 'PASS: Windows v0.3.0 setup builder is x64, evidence-gated, embedded, and nonpublishing'
