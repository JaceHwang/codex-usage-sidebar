[CmdletBinding(DefaultParameterSetName = 'Build')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Build')]
    [string] $ValidationEvidence,

    [Parameter(Mandatory = $true, ParameterSetName = 'Build')]
    [string] $OutputDirectory,

    [Parameter(ParameterSetName = 'Plan')]
    [switch] $PlanOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$version = '0.3.0'
$architecture = 'x64'
$runtimeIdentifier = 'win-x64'
$requiredBranch = 'v0.3.0'
$artifactName = 'codex-usage-sidebar-v0.3.0-windows-x64-setup.exe'
$codexRuntimeSource = 'https://github.com/openai/codex/releases/download/rust-v0.147.0/codex-x86_64-pc-windows-msvc.exe'
$codexRuntimeSha256 = '935a1911ed2556e4ffcec995f4886ac2ac425863ba26fed264df62e30272ad9d'

$plan = [ordered]@{
    schemaVersion = 1
    status = 'release-setup-plan'
    version = $version
    architecture = $architecture
    runtimeIdentifier = $runtimeIdentifier
    minimumWindowsBuild = 22000
    requiredBranch = $requiredBranch
    artifactName = $artifactName
    requiresCompleteRealDeviceEvidence = $true
    embeddedPayload = $true
    singleFileSetup = $true
    publishesGitHubRelease = $false
}
if ($PlanOnly) {
    $plan | ConvertTo-Json -Depth 3
    exit 0
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$repoRootFull = [IO.Path]::GetFullPath($repoRoot).TrimEnd([IO.Path]::DirectorySeparatorChar)
Import-Module (Join-Path $PSScriptRoot 'WindowsDevicePayload.Source.psm1') -Force
Assert-WindowsDevicePlatform `
    -IsWindows ([Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([Runtime.InteropServices.OSPlatform]::Windows)) `
    -Architecture ([Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString().ToLowerInvariant()) `
    -WindowsBuild ([Environment]::OSVersion.Version.Build)

$branch = (& git -C $repoRoot branch --show-current | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $branch -ne $requiredBranch) {
    throw "Windows v0.3.0 setup must be built from the exact '$requiredBranch' branch."
}
$porcelain = (& git -C $repoRoot status --porcelain=v1 --untracked-files=all | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $porcelain.Length -ne 0) {
    throw 'Windows v0.3.0 setup requires a completely clean worktree, including untracked files.'
}
$packagingCommit = Assert-WindowsDeviceSourceState -RepositoryRoot $repoRoot -BuildInputRoots @('.')

$evidencePath = (Resolve-Path -LiteralPath $ValidationEvidence).Path
$evidenceFull = [IO.Path]::GetFullPath($evidencePath)
$repoPrefix = $repoRootFull + [IO.Path]::DirectorySeparatorChar
if (-not $evidenceFull.StartsWith($repoPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Windows validation evidence must be a committed file inside the repository.'
}
$evidenceRelative = $evidenceFull.Substring($repoPrefix.Length).Replace('\', '/')
if ($evidenceRelative -ne 'docs/validation/windows-v0.3.0.json') {
    throw 'Windows v0.3.0 setup requires the canonical committed validation evidence path.'
}
& git -C $repoRoot ls-files --error-unmatch -- $evidenceRelative | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw 'Windows validation evidence must be tracked by Git at HEAD.'
}
$evidenceDocument = Get-Content -Raw -LiteralPath $evidenceFull | ConvertFrom-Json
$sourceCommit = [string] $evidenceDocument.sourceCommit
$deltaVerifier = Join-Path $repoRoot 'scripts\verify-v030-packaging-delta.py'
& python $deltaVerifier `
    --repository $repoRoot `
    --validated-source-commit $sourceCommit `
    --packaging-commit $packagingCommit `
    --allowed-path $evidenceRelative
if ($LASTEXITCODE -ne 0) {
    throw 'The Windows packaging commit changed files after real-device validation.'
}

$validationVerifier = Join-Path $repoRoot 'scripts\verify-windows-v030-validation.py'
& python $validationVerifier $evidenceFull --source-commit $sourceCommit
if ($LASTEXITCODE -ne 0) {
    throw 'The complete Windows v0.3.0 real-device evidence gate failed.'
}

$output = [IO.Path]::GetFullPath($OutputDirectory)
if ([string]::Equals($output, $repoRootFull, [StringComparison]::OrdinalIgnoreCase) -or
    $output.StartsWith($repoPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The setup output directory must be outside the repository tree.'
}
New-Item -ItemType Directory -Force -Path $output | Out-Null
$finalSetup = Join-Path $output $artifactName
$provenancePath = Join-Path $output 'WINDOWS-V030-PROVENANCE.json'
$checksumsPath = Join-Path $output 'WINDOWS-V030-SHA256SUMS.txt'
foreach ($target in @($finalSetup, $provenancePath, $checksumsPath)) {
    if (Test-Path -LiteralPath $target) {
        throw "Refusing to overwrite an existing release candidate file: $target"
    }
}

$localAppData = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
$buildRoot = Join-Path $localAppData 'CodexUsageSidebar\SetupBuild'
$operationRoot = Join-Path $buildRoot ('.stage-' + [Guid]::NewGuid().ToString('N'))
$payload = Join-Path $operationRoot 'payload'
$installerOutput = Join-Path $operationRoot 'installer'
New-Item -ItemType Directory -Force -Path $payload, $installerOutput | Out-Null

try {
    $framework = 'net8.0-windows10.0.19041.0'
    $commonPublishProperties = @(
        '--configuration', 'Release',
        '--framework', $framework,
        '--runtime', $runtimeIdentifier,
        '--self-contained', 'true',
        '-p:PublishTrimmed=false',
        '-p:DebugType=None',
        '-p:DebugSymbols=false',
        "-p:SourceRevisionId=$sourceCommit",
        '--nologo'
    )
    $controlProject = Join-Path $repoRoot 'plugins\codex-usage-sidebar\windows\src\CodexUsageSidebar.Control\CodexUsageSidebar.Control.csproj'
    & dotnet publish $controlProject @commonPublishProperties `
        '-p:PublishSingleFile=false' --output $payload
    if ($LASTEXITCODE -ne 0) { throw 'The Windows v0.3.0 Host/Control publish failed.' }
    foreach ($required in @('CodexUsageSidebar.Windows.exe', 'CodexUsageSidebar.Control.exe')) {
        if (-not (Test-Path -LiteralPath (Join-Path $payload $required) -PathType Leaf)) {
            throw "The Windows v0.3.0 payload is missing $required."
        }
    }

    $runtimePath = Join-Path $payload 'codex.exe'
    $runtimeCandidates = @(
        (Join-Path $localAppData 'CodexUsageSidebar\Current\codex.exe')
    ) + @(Get-ChildItem -Path (Join-Path $repoRoot '.dist\windows-device-test\*\codex.exe') `
            -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    $runtimeReused = Copy-WindowsDeviceRuntimeFromCache `
        -Candidates $runtimeCandidates `
        -Destination $runtimePath `
        -ExpectedSha256 $codexRuntimeSha256
    if (-not $runtimeReused) {
        Invoke-WebRequest -Uri $codexRuntimeSource -OutFile $runtimePath -UseBasicParsing
    }
    $actualRuntimeSha256 = (Get-FileHash -LiteralPath $runtimePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualRuntimeSha256 -ne $codexRuntimeSha256) {
        throw "The official Codex x64 runtime digest is invalid: $actualRuntimeSha256"
    }

    $wideFixture = Join-Path $repoRoot 'plugins\codex-usage-sidebar\contracts\uia\windows-codex-151.0.7922.76-default-200.json'
    $narrowFixture = Join-Path $repoRoot 'plugins\codex-usage-sidebar\contracts\uia\windows-codex-151.0.7922.76-narrow-200.json'
    $selectorsJson = New-WindowsDeviceSelectorsDocument -FixturePaths @($wideFixture, $narrowFixture) |
        ConvertTo-Json -Depth 5
    [IO.File]::WriteAllText(
        (Join-Path $payload 'selectors.json'),
        $selectorsJson + [Environment]::NewLine,
        [Text.UTF8Encoding]::new($false))

    $manifestBuilder = Join-Path $repoRoot 'scripts\build-windows-v030-release-manifest.py'
    $payloadVerifier = Join-Path $repoRoot 'scripts\verify-windows-v030-release-payload.py'
    & python $manifestBuilder --payload-dir $payload --version $version --architecture $architecture `
        --source-commit $sourceCommit --codex-source $codexRuntimeSource `
        --codex-sha256 $codexRuntimeSha256 --validation-evidence $evidenceFull
    if ($LASTEXITCODE -ne 0) { throw 'The Windows v0.3.0 release manifest build failed.' }
    & python $payloadVerifier $payload
    if ($LASTEXITCODE -ne 0) { throw 'The Windows v0.3.0 release payload verification failed.' }
    $manifestSha256 = (Get-FileHash -LiteralPath (Join-Path $payload 'windows-payload.json') -Algorithm SHA256).Hash.ToLowerInvariant()
    $validationSha256 = (Get-FileHash -LiteralPath (Join-Path $payload 'windows-validation.json') -Algorithm SHA256).Hash.ToLowerInvariant()

    $installerProject = Join-Path $repoRoot 'plugins\codex-usage-sidebar\windows\src\CodexUsageSidebar.Installer\CodexUsageSidebar.Installer.csproj'
    & dotnet publish $installerProject @commonPublishProperties `
        '-p:PublishSingleFile=true' `
        '-p:IncludeNativeLibrariesForSelfExtract=true' `
        '-p:InstallerPayloadMode=embedded-release' `
        "-p:InstallerDisplayVersion=$version" `
        "-p:EmbeddedPayloadDirectory=$payload" `
        "-p:EmbeddedPayloadVersion=$version" `
        "-p:EmbeddedSourceCommit=$sourceCommit" `
        "-p:EmbeddedPayloadManifestSha256=$manifestSha256" `
        "-p:EmbeddedCodexRuntimeSource=$codexRuntimeSource" `
        "-p:EmbeddedCodexRuntimeSha256=$codexRuntimeSha256" `
        --output $installerOutput
    if ($LASTEXITCODE -ne 0) { throw 'The embedded Windows v0.3.0 setup publish failed.' }
    $builtSetup = Join-Path $installerOutput 'CodexUsageSidebar.Installer.exe'
    if (-not (Test-Path -LiteralPath $builtSetup -PathType Leaf)) {
        throw 'The embedded Windows v0.3.0 setup output is incomplete.'
    }

    & $builtSetup --verify-embedded
    if ($LASTEXITCODE -ne 0) {
        throw 'The Windows v0.3.0 setup failed its embedded payload self-verification.'
    }
    Copy-Item -LiteralPath $builtSetup -Destination $finalSetup
    $setupSha256 = (Get-FileHash -LiteralPath $finalSetup -Algorithm SHA256).Hash.ToLowerInvariant()
    $authenticode = Get-AuthenticodeSignature -LiteralPath $finalSetup
    $provenance = [ordered]@{
        schemaVersion = 1
        status = 'release-candidate'
        version = $version
        architecture = $architecture
        runtimeIdentifier = $runtimeIdentifier
        sourceCommit = $sourceCommit
        validatedSourceCommit = $sourceCommit
        packagingCommit = $packagingCommit
        artifact = $artifactName
        sha256 = $setupSha256
        payloadManifestSha256 = $manifestSha256
        validationEvidenceSha256 = $validationSha256
        codexRuntime = [ordered]@{
            source = $codexRuntimeSource
            sha256 = $codexRuntimeSha256
        }
        realDeviceValidated = $true
        publishableInstaller = $true
        authenticodeStatus = $authenticode.Status.ToString()
        signerSubject = if ($null -ne $authenticode.SignerCertificate) { $authenticode.SignerCertificate.Subject } else { $null }
        createdAt = [DateTimeOffset]::UtcNow.ToString('o')
    }
    [IO.File]::WriteAllText(
        $provenancePath,
        ($provenance | ConvertTo-Json -Depth 5) + [Environment]::NewLine,
        [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText(
        $checksumsPath,
        "$setupSha256  $artifactName" + [Environment]::NewLine,
        [Text.UTF8Encoding]::new($false))

    $setupVerifier = Join-Path $repoRoot 'scripts\verify-windows-v030-setup.ps1'
    & $setupVerifier `
        -CandidateDirectory $output `
        -SourceCommit $sourceCommit `
        -PackagingCommit $packagingCommit
    if ($LASTEXITCODE -ne 0) {
        throw 'The copied Windows v0.3.0 setup candidate failed final verification.'
    }

    [ordered]@{
        setup = $finalSetup
        provenance = $provenancePath
        checksums = $checksumsPath
        sourceCommit = $sourceCommit
        packagingCommit = $packagingCommit
        sha256 = $setupSha256
        authenticodeStatus = $authenticode.Status.ToString()
    } | ConvertTo-Json -Depth 3
}
finally {
    if (Test-Path -LiteralPath $operationRoot) {
        $resolvedBuildRoot = [IO.Path]::GetFullPath($buildRoot).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
        $resolvedOperationRoot = [IO.Path]::GetFullPath($operationRoot)
        if (-not $resolvedOperationRoot.StartsWith($resolvedBuildRoot, [StringComparison]::OrdinalIgnoreCase) -or
            -not ([IO.Path]::GetFileName($resolvedOperationRoot)).StartsWith('.stage-', [StringComparison]::Ordinal)) {
            throw 'Refusing to clean an unexpected Windows setup staging path.'
        }
        Remove-Item -LiteralPath $operationRoot -Recurse -Force
    }
}
