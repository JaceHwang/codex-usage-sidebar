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

$releaseProfile = (& python -c 'import json,sys; sys.path.insert(0,sys.argv[1]); from v033_release_profiles import FORMAL; print(json.dumps(dict(FORMAL)))' $PSScriptRoot | ConvertFrom-Json)
if ($LASTEXITCODE -ne 0 -or $releaseProfile.releaseProfile -ne 'formal' -or $releaseProfile.tag -ne 'v0.3.3' -or $releaseProfile.realDeviceValidated -ne $true) {
    throw 'Windows v0.3.3 setup could not load the immutable formal release profile.'
}
$version = $releaseProfile.tag.TrimStart('v')
$architecture = 'x64'
$runtimeIdentifier = 'win-x64'
$requiredBranch = 'v0.3.3'
$artifactName = 'codex-usage-sidebar-v0.3.3-windows-x64-setup.exe'
$canonicalEvidence = $releaseProfile.evidencePath
$codexRuntimeSource = 'https://github.com/openai/codex/releases/download/rust-v0.147.0/codex-x86_64-pc-windows-msvc.exe'
$codexRuntimeSha256 = '935a1911ed2556e4ffcec995f4886ac2ac425863ba26fed264df62e30272ad9d'
$repoRoot = Split-Path -Parent $PSScriptRoot
$repoRootFull = [IO.Path]::GetFullPath($repoRoot).TrimEnd([IO.Path]::DirectorySeparatorChar)
$repoPrefix = $repoRootFull + [IO.Path]::DirectorySeparatorChar
Import-Module (Join-Path $PSScriptRoot 'WindowsDevicePayload.Source.psm1') -Force
Assert-WindowsDevicePlatform `
    -IsWindows ([Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([Runtime.InteropServices.OSPlatform]::Windows)) `
    -Architecture ([Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString().ToLowerInvariant()) `
    -WindowsBuild ([Environment]::OSVersion.Version.Build)

$branch = (& git -C $repoRoot branch --show-current | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $branch -ne $requiredBranch) {
    throw "Windows v0.3.3 setup must be built from the exact '$requiredBranch' branch."
}
$porcelain = (& git -C $repoRoot status --porcelain=v1 --untracked-files=all | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $porcelain.Length -ne 0) {
    throw 'Windows v0.3.3 setup requires a completely clean worktree, including untracked files.'
}
$packagingCommit = Assert-WindowsDeviceSourceState -RepositoryRoot $repoRoot -BuildInputRoots @('.')
$evidencePath = (Resolve-Path -LiteralPath $ValidationEvidence).Path
$evidenceFull = [IO.Path]::GetFullPath($evidencePath)
if (-not $evidenceFull.StartsWith($repoPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Windows v0.3.3 validation evidence must be a committed file inside the repository.'
}
$evidenceRelative = $evidenceFull.Substring($repoPrefix.Length).Replace('\', '/')
if ($evidenceRelative -ne $canonicalEvidence) {
    throw "Windows v0.3.3 setup requires the canonical '$canonicalEvidence' validation evidence path."
}
& git -C $repoRoot ls-files --error-unmatch -- $evidenceRelative | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Windows v0.3.3 validation evidence must be tracked by Git at HEAD.' }
$evidenceDocument = Get-Content -Raw -LiteralPath $evidenceFull | ConvertFrom-Json
$sourceCommit = [string] $evidenceDocument.sourceCommit
if ($sourceCommit -ne $packagingCommit) {
    throw 'Windows v0.3.3 packaging commit must exactly match the real-device validation source commit.'
}
& python (Join-Path $PSScriptRoot 'verify-windows-v033-validation.py') $evidenceFull --source-commit $sourceCommit
if ($LASTEXITCODE -ne 0) { throw 'The Windows v0.3.3 formal evidence gate failed.' }

$output = [IO.Path]::GetFullPath($OutputDirectory)
if ([string]::Equals($output, $repoRootFull, [StringComparison]::OrdinalIgnoreCase) -or $output.StartsWith($repoPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The setup output directory must be outside the repository tree.'
}
New-Item -ItemType Directory -Force -Path $output | Out-Null
$finalSetup = Join-Path $output $artifactName
$provenancePath = Join-Path $output 'WINDOWS-V033-PROVENANCE.json'
$checksumsPath = Join-Path $output 'WINDOWS-V033-SHA256SUMS.txt'
foreach ($target in @($finalSetup, $provenancePath, $checksumsPath)) {
    if (Test-Path -LiteralPath $target) { throw "Refusing to overwrite an existing release candidate file: $target" }
}
$buildRoot = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)) 'CodexUsageSidebar\SetupBuild'
$operationRoot = Join-Path $buildRoot ('.stage-' + [Guid]::NewGuid().ToString('N'))
$payload = Join-Path $operationRoot 'payload'
$installerOutput = Join-Path $operationRoot 'installer'
New-Item -ItemType Directory -Force -Path $payload, $installerOutput | Out-Null
try {
    $framework = 'net8.0-windows10.0.19041.0'
    $properties = @('--configuration', 'Release', '--framework', $framework, '--runtime', $runtimeIdentifier, '--self-contained', 'true', '-p:PublishTrimmed=false', '-p:DebugType=None', '-p:DebugSymbols=false', "-p:SourceRevisionId=$sourceCommit", '--nologo')
    $controlProject = Join-Path $repoRoot 'plugins\codex-usage-sidebar\windows\src\CodexUsageSidebar.Control\CodexUsageSidebar.Control.csproj'
    & dotnet publish $controlProject @properties '-p:PublishSingleFile=false' --output $payload
    if ($LASTEXITCODE -ne 0) { throw 'The Windows v0.3.3 Host/Control publish failed.' }
    foreach ($required in @('CodexUsageSidebar.Windows.exe', 'CodexUsageSidebar.Control.exe')) {
        if (-not (Test-Path -LiteralPath (Join-Path $payload $required) -PathType Leaf)) { throw "The Windows v0.3.3 payload is missing $required." }
    }
    $runtimePath = Join-Path $payload 'codex.exe'
    $runtimeCandidates = @((Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)) 'CodexUsageSidebar\Current\codex.exe')) + @(Get-ChildItem -Path (Join-Path $repoRoot '.dist\windows-device-test\*\codex.exe') -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    if (-not (Copy-WindowsDeviceRuntimeFromCache -Candidates $runtimeCandidates -Destination $runtimePath -ExpectedSha256 $codexRuntimeSha256)) { Invoke-WebRequest -Uri $codexRuntimeSource -OutFile $runtimePath -UseBasicParsing }
    if ((Get-FileHash -LiteralPath $runtimePath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $codexRuntimeSha256) { throw 'The official Codex x64 runtime digest is invalid.' }
    $fixtures = @('windows-codex-151.0.7922.76-default-200.json', 'windows-codex-151.0.7922.76-default-flat-200.json', 'windows-codex-151.0.7922.76-narrow-200.json') | ForEach-Object { Join-Path $repoRoot ('plugins\codex-usage-sidebar\contracts\uia\' + $_) }
    $selectors = New-WindowsDeviceSelectorsDocument -FixturePaths $fixtures | ConvertTo-Json -Depth 5
    [IO.File]::WriteAllText((Join-Path $payload 'selectors.json'), $selectors + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
    $compatibilityConfiguration = [ordered]@{ schemaVersion = 1; publicKey = $CompatibilityPublicKey; updateUri = $CompatibilityUpdateUri }
    [IO.File]::WriteAllText((Join-Path $payload 'compatibility-update.json'), ($compatibilityConfiguration | ConvertTo-Json -Depth 3) + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
    & python (Join-Path $PSScriptRoot 'build-windows-v033-release-manifest.py') --payload-dir $payload --version $version --architecture $architecture --source-commit $sourceCommit --codex-source $codexRuntimeSource --codex-sha256 $codexRuntimeSha256 --validation-evidence $evidenceFull
    if ($LASTEXITCODE -ne 0) { throw 'The Windows v0.3.3 release manifest build failed.' }
    & python (Join-Path $PSScriptRoot 'verify-windows-v033-release-payload.py') $payload
    if ($LASTEXITCODE -ne 0) { throw 'The Windows v0.3.3 release payload verification failed.' }
    $manifestSha256 = (Get-FileHash -LiteralPath (Join-Path $payload 'windows-payload.json') -Algorithm SHA256).Hash.ToLowerInvariant()
    $validationSha256 = (Get-FileHash -LiteralPath (Join-Path $payload 'windows-validation.json') -Algorithm SHA256).Hash.ToLowerInvariant()
    $compatibilitySha256 = (Get-FileHash -LiteralPath (Join-Path $payload 'compatibility-update.json') -Algorithm SHA256).Hash.ToLowerInvariant()
    $installerProject = Join-Path $repoRoot 'plugins\codex-usage-sidebar\windows\src\CodexUsageSidebar.Installer\CodexUsageSidebar.Installer.csproj'
    & dotnet publish $installerProject @properties '-p:PublishSingleFile=true' '-p:IncludeNativeLibrariesForSelfExtract=true' '-p:InstallerPayloadMode=embedded-release' "-p:InstallerDisplayVersion=$version" "-p:EmbeddedPayloadDirectory=$payload" "-p:EmbeddedPayloadVersion=$version" "-p:EmbeddedSourceCommit=$sourceCommit" "-p:EmbeddedPayloadManifestSha256=$manifestSha256" "-p:EmbeddedCodexRuntimeSource=$codexRuntimeSource" "-p:EmbeddedCodexRuntimeSha256=$codexRuntimeSha256" --output $installerOutput
    if ($LASTEXITCODE -ne 0) { throw 'The embedded Windows v0.3.3 setup publish failed.' }
    $builtSetup = Join-Path $installerOutput 'CodexUsageSidebar.Installer.exe'
    if (-not (Test-Path -LiteralPath $builtSetup -PathType Leaf)) { throw 'The embedded Windows v0.3.3 setup output is incomplete.' }
    & $builtSetup --verify-embedded
    if ($LASTEXITCODE -ne 0) { throw 'The Windows v0.3.3 setup failed its embedded payload self-verification.' }
    Copy-Item -LiteralPath $builtSetup -Destination $finalSetup
    $setupSha256 = (Get-FileHash -LiteralPath $finalSetup -Algorithm SHA256).Hash.ToLowerInvariant()
    $authenticode = Get-AuthenticodeSignature -LiteralPath $finalSetup
    $provenance = [ordered]@{ schemaVersion = 1; status = 'release-candidate'; version = $version; architecture = $architecture; runtimeIdentifier = $runtimeIdentifier; sourceCommit = $sourceCommit; validatedSourceCommit = $sourceCommit; packagingCommit = $packagingCommit; artifact = $artifactName; sha256 = $setupSha256; payloadManifestSha256 = $manifestSha256; validationEvidenceSha256 = $validationSha256; compatibilityConfigurationSha256 = $compatibilitySha256; codexRuntime = [ordered]@{ source = $codexRuntimeSource; sha256 = $codexRuntimeSha256 }; realDeviceValidated = $true; publishableInstaller = $true; authenticodeStatus = $authenticode.Status.ToString(); signerSubject = if ($null -ne $authenticode.SignerCertificate) { $authenticode.SignerCertificate.Subject } else { $null }; createdAt = [DateTimeOffset]::UtcNow.ToString('o') }
    [IO.File]::WriteAllText($provenancePath, ($provenance | ConvertTo-Json -Depth 5) + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($checksumsPath, "$setupSha256  $artifactName" + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
    & (Join-Path $PSScriptRoot 'verify-windows-v033-setup.ps1') -CandidateDirectory $output -SourceCommit $sourceCommit -PackagingCommit $packagingCommit
    if ($LASTEXITCODE -ne 0) { throw 'The copied Windows v0.3.3 setup candidate failed final verification.' }
    [ordered]@{ setup = $finalSetup; provenance = $provenancePath; checksums = $checksumsPath; sourceCommit = $sourceCommit; packagingCommit = $packagingCommit; sha256 = $setupSha256 } | ConvertTo-Json -Depth 3
} finally {
    if (Test-Path -LiteralPath $operationRoot) {
        $safeRoot = [IO.Path]::GetFullPath($buildRoot).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
        $safeOperation = [IO.Path]::GetFullPath($operationRoot)
        if (-not $safeOperation.StartsWith($safeRoot, [StringComparison]::OrdinalIgnoreCase) -or -not ([IO.Path]::GetFileName($safeOperation)).StartsWith('.stage-', [StringComparison]::Ordinal)) { throw 'Refusing to clean an unexpected Windows setup staging path.' }
        Remove-Item -LiteralPath $operationRoot -Recurse -Force
    }
}
