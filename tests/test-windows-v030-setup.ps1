$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$script = Join-Path $repoRoot 'scripts\build-windows-v030-setup.ps1'
$verifier = Join-Path $repoRoot 'scripts\verify-windows-v030-setup.ps1'
$sourceCommit = '0123456789abcdef0123456789abcdef01234567'
$packagingCommit = 'fedcba9876543210fedcba9876543210fedcba98'

$formalPlan = (& $script -PlanOnly | Out-String) | ConvertFrom-Json
$explicitFormalPlan = (& $script -PlanOnly -ReleaseProfile formal | Out-String) | ConvertFrom-Json
$quickPlan = (& $script -PlanOnly -ReleaseProfile quick-prerelease | Out-String) | ConvertFrom-Json
if ($formalPlan.version -ne '0.3.0' -or
    $formalPlan.architecture -ne 'x64' -or
    $formalPlan.runtimeIdentifier -ne 'win-x64' -or
    $formalPlan.requiredBranch -ne 'v0.3.0' -or
    $formalPlan.artifactName -ne 'codex-usage-sidebar-v0.3.0-windows-x64-setup.exe' -or
    $formalPlan.releaseProfile -ne 'formal' -or
    $formalPlan.releaseTag -ne 'v0.3.0' -or
    $formalPlan.validationEvidencePath -ne 'docs/validation/windows-v0.3.0.json' -or
    $formalPlan.requiresCompleteRealDeviceEvidence -ne $true -or
    $formalPlan.realDeviceValidated -ne $true) {
    throw 'The default Windows v0.3.0 formal setup plan changed semantics.'
}
if (($explicitFormalPlan | ConvertTo-Json -Compress) -ne ($formalPlan | ConvertTo-Json -Compress)) {
    throw 'The explicit formal setup plan differs from the formal default.'
}
if ($quickPlan.releaseProfile -ne 'quick-prerelease' -or
    $quickPlan.releaseTag -ne 'v0.3.0-rc.1' -or
    $quickPlan.validationEvidencePath -ne 'docs/validation/windows-v0.3.0-quick-prerelease.json' -or
    $quickPlan.requiresCompleteRealDeviceEvidence -ne $false -or
    $quickPlan.realDeviceValidated -ne $false -or
    $quickPlan.requiredBranch -ne 'v0.3.0' -or
    $quickPlan.artifactName -ne $formalPlan.artifactName) {
    throw 'The Windows quick-prerelease setup plan is not bound to its exact profile.'
}

$invalidProfileRejected = $false
try {
    & $script -PlanOnly -ReleaseProfile unsupported | Out-Null
}
catch {
    $invalidProfileRejected = $true
}
if (-not $invalidProfileRejected) {
    throw 'The Windows setup builder accepted an unsupported release profile.'
}

$content = Get-Content -Raw -LiteralPath $script
foreach ($required in @(
    'verify-windows-v030-validation.py',
    'verify-windows-v030-quick-prerelease.py',
    'verify-v030-packaging-delta.py',
    'build-windows-v030-release-manifest.py',
    'verify-windows-v030-release-payload.py',
    '--verify-embedded',
    'InstallerPayloadMode=embedded-release',
    'validatedSourceCommit',
    'packagingCommit',
    'status --porcelain=v1 --untracked-files=all',
    "'v0.3.0'",
    'ReleaseProfile'
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
    'Get-AuthenticodeSignature',
    'ReleaseProfile'
)) {
    if (-not $verifierContent.Contains($required)) {
        throw "The Windows setup verifier is missing a required check: $required"
    }
}

$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('cus-v030-setup-profile-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixtureRoot | Out-Null
try {
    function New-CandidateFixture {
        param(
            [Parameter(Mandatory = $true)] [string] $Name,
            [AllowNull()] [string] $ValidationProfile,
            [Parameter(Mandatory = $true)] [bool] $RealDeviceValidated
        )
        $directory = Join-Path $fixtureRoot $Name
        New-Item -ItemType Directory -Path $directory | Out-Null
        $artifactName = 'codex-usage-sidebar-v0.3.0-windows-x64-setup.exe'
        $setup = Join-Path $directory $artifactName
        [IO.File]::WriteAllText($setup, 'not executed because profile checks run first', [Text.UTF8Encoding]::new($false))
        $sha256 = (Get-FileHash -LiteralPath $setup -Algorithm SHA256).Hash.ToLowerInvariant()
        [IO.File]::WriteAllText(
            (Join-Path $directory 'WINDOWS-V030-SHA256SUMS.txt'),
            "$sha256  $artifactName`n",
            [Text.UTF8Encoding]::new($false))
        $provenance = [ordered]@{
            schemaVersion = 1
            status = 'release-candidate'
            version = '0.3.0'
            architecture = 'x64'
            runtimeIdentifier = 'win-x64'
            sourceCommit = $sourceCommit
            validatedSourceCommit = $sourceCommit
            packagingCommit = $packagingCommit
            artifact = $artifactName
            sha256 = $sha256
            payloadManifestSha256 = ('b' * 64)
            validationEvidenceSha256 = ('c' * 64)
            codexRuntime = [ordered]@{
                source = 'https://github.com/openai/codex/releases/download/rust-v0.147.0/codex-x86_64-pc-windows-msvc.exe'
                sha256 = '935a1911ed2556e4ffcec995f4886ac2ac425863ba26fed264df62e30272ad9d'
            }
            realDeviceValidated = $RealDeviceValidated
            publishableInstaller = $true
            authenticodeStatus = 'NotSigned'
            signerSubject = $null
        }
        if ($null -ne $ValidationProfile) {
            $provenance['validationProfile'] = $ValidationProfile
        }
        [IO.File]::WriteAllText(
            (Join-Path $directory 'WINDOWS-V030-PROVENANCE.json'),
            ($provenance | ConvertTo-Json -Depth 5) + "`n",
            [Text.UTF8Encoding]::new($false))
        return $directory
    }

    function Assert-ProfileRejected {
        param(
            [Parameter(Mandatory = $true)] [string] $CandidateDirectory,
            [Parameter(Mandatory = $true)] [string] $ReleaseProfile,
            [Parameter(Mandatory = $true)] [string] $Label
        )
        try {
            & $verifier `
                -CandidateDirectory $CandidateDirectory `
                -SourceCommit $sourceCommit `
                -PackagingCommit $packagingCommit `
                -ReleaseProfile $ReleaseProfile | Out-Null
        }
        catch {
            if ($_.Exception.Message -notmatch '(?i)profile|provenance|validated') {
                throw "$Label failed for an unrelated reason: $($_.Exception.Message)"
            }
            return
        }
        throw "$Label unexpectedly passed setup verification."
    }

    $formal = New-CandidateFixture -Name formal -ValidationProfile $null -RealDeviceValidated $true
    $quick = New-CandidateFixture -Name quick -ValidationProfile quick-prerelease -RealDeviceValidated $false
    $quickValidated = New-CandidateFixture -Name quick-validated -ValidationProfile quick-prerelease -RealDeviceValidated $true
    $formalUnvalidated = New-CandidateFixture -Name formal-unvalidated -ValidationProfile $null -RealDeviceValidated $false
    $wrongMarker = New-CandidateFixture -Name wrong-marker -ValidationProfile formal -RealDeviceValidated $false

    Assert-ProfileRejected -CandidateDirectory $quick -ReleaseProfile formal -Label 'Formal verifier accepted quick provenance'
    Assert-ProfileRejected -CandidateDirectory $formal -ReleaseProfile quick-prerelease -Label 'Quick verifier accepted formal provenance'
    Assert-ProfileRejected -CandidateDirectory $quickValidated -ReleaseProfile quick-prerelease -Label 'Quick verifier accepted real-device validation'
    Assert-ProfileRejected -CandidateDirectory $formalUnvalidated -ReleaseProfile formal -Label 'Formal verifier accepted missing real-device validation'
    Assert-ProfileRejected -CandidateDirectory $wrongMarker -ReleaseProfile quick-prerelease -Label 'Quick verifier accepted a formal marker'
}
finally {
    if (Test-Path -LiteralPath $fixtureRoot) {
        $tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
        $resolvedFixture = [IO.Path]::GetFullPath($fixtureRoot)
        if (-not $resolvedFixture.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -or
            -not ([IO.Path]::GetFileName($resolvedFixture)).StartsWith('cus-v030-setup-profile-', [StringComparison]::Ordinal)) {
            throw 'Refusing to clean an unexpected setup profile fixture path.'
        }
        Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
    }
}

Write-Output 'PASS: Windows v0.3.0 setup builder and verifier enforce exact formal/quick profiles'
