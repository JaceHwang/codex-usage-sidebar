$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not [Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([Runtime.InteropServices.OSPlatform]::Windows) -or
    [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString() -ne 'X64') {
    throw 'The embedded Windows setup integration test requires AMD64/x64 Windows.'
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('cus-embedded-setup-' + [Guid]::NewGuid().ToString('N'))
$payload = Join-Path $fixtureRoot 'payload'
$output = Join-Path $fixtureRoot 'output'
$sourceCommit = '0123456789abcdef0123456789abcdef01234567'
$runtimeSource = 'https://github.com/openai/codex/releases/download/test/codex.exe'
New-Item -ItemType Directory -Path $payload, $output | Out-Null

try {
    $smoke = [ordered]@{
        embeddedPayload = 'pass'
        manager = 'pass'
        runtime = 'pass'
        redactedProbe = [ordered]@{
            result = 'pass'
            includesText = $false
            rawNodeNameCount = 0
        }
    }
    $validationEvidence = [ordered]@{
        schemaVersion = 1
        releaseProfile = 'quick-prerelease'
        version = '0.3.0'
        sourceCommit = $sourceCommit
        architecture = 'x64'
        windowsBuild = 26100
        codexFileBuild = '151.0.7922.76'
        completedAt = '2026-08-13T00:00:00Z'
        smoke = $smoke
    } | ConvertTo-Json -Depth 6
    $contents = [ordered]@{
        'CodexUsageSidebar.Windows.exe' = 'host'
        'CodexUsageSidebar.Control.exe' = 'control'
        'codex.exe' = 'runtime'
        'selectors.json' = '{}'
        'windows-validation.json' = $validationEvidence
    }
    foreach ($entry in $contents.GetEnumerator()) {
        [IO.File]::WriteAllText(
            (Join-Path $payload $entry.Key),
            $entry.Value,
            [Text.UTF8Encoding]::new($false))
    }
    $files = [ordered]@{}
    foreach ($name in $contents.Keys) {
        $files[$name] = (Get-FileHash -LiteralPath (Join-Path $payload $name) -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    $manifest = [ordered]@{
        schemaVersion = 1
        version = '0.3.0'
        architecture = 'x64'
        sourceCommit = $sourceCommit
        status = 'release'
        validationProfile = 'quick-prerelease'
        realDeviceValidated = $false
        publishableInstaller = $true
        codexRuntime = [ordered]@{
            source = $runtimeSource
            sha256 = $files['codex.exe']
        }
        quickPrereleaseValidation = [ordered]@{
            sha256 = $files['windows-validation.json']
            windowsBuild = 26100
            codexFileBuild = '151.0.7922.76'
            completedAt = '2026-08-13T00:00:00Z'
            smoke = $smoke
        }
        files = $files
    }
    [IO.File]::WriteAllText(
        (Join-Path $payload 'windows-payload.json'),
        ($manifest | ConvertTo-Json -Depth 6),
        [Text.UTF8Encoding]::new($false))
    $manifestSha256 = (Get-FileHash -LiteralPath (Join-Path $payload 'windows-payload.json') -Algorithm SHA256).Hash.ToLowerInvariant()

    $project = Join-Path $repoRoot 'plugins\codex-usage-sidebar\windows\src\CodexUsageSidebar.Installer\CodexUsageSidebar.Installer.csproj'
    & dotnet publish $project `
        --configuration Release `
        --framework net8.0-windows10.0.19041.0 `
        --runtime win-x64 `
        --self-contained true `
        '-p:PublishSingleFile=true' `
        '-p:IncludeNativeLibrariesForSelfExtract=true' `
        '-p:PublishTrimmed=false' `
        '-p:DebugType=None' `
        '-p:DebugSymbols=false' `
        '-p:InstallerPayloadMode=embedded-release' `
        '-p:InstallerDisplayVersion=0.3.0' `
        "-p:EmbeddedPayloadDirectory=$payload" `
        '-p:EmbeddedPayloadVersion=0.3.0' `
        "-p:EmbeddedSourceCommit=$sourceCommit" `
        "-p:EmbeddedPayloadManifestSha256=$manifestSha256" `
        "-p:EmbeddedCodexRuntimeSource=$runtimeSource" `
        "-p:EmbeddedCodexRuntimeSha256=$($files['codex.exe'])" `
        --output $output `
        --nologo
    if ($LASTEXITCODE -ne 0) { throw 'The embedded Windows setup integration publish failed.' }

    $setup = Join-Path $output 'CodexUsageSidebar.Installer.exe'
    if (-not (Test-Path -LiteralPath $setup -PathType Leaf)) {
        throw 'The embedded Windows setup integration output is missing.'
    }
    Import-Module (Join-Path $repoRoot 'plugins\codex-usage-sidebar\scripts\WindowsProcessCommandLine.psm1') -Force
    $verifyExitCode = Invoke-WindowsProcessAndWait -FileName $setup -Arguments @('--verify-embedded')
    if ($verifyExitCode -ne 0) {
        throw "The embedded Windows setup self-verification failed with exit code $verifyExitCode."
    }
    $externalExitCode = Invoke-WindowsProcessAndWait -FileName $setup -Arguments @('--device-install', $payload)
    if ($externalExitCode -ne 70) {
        throw "The embedded Windows setup accepted an external payload path (exit $externalExitCode)."
    }
    if (Get-ChildItem -LiteralPath $output -File | Where-Object { $_.Name -in $contents.Keys -or $_.Name -eq 'windows-payload.json' }) {
        throw 'The single-file Windows setup leaked loose payload files.'
    }

    Write-Output 'PASS: Windows single-file setup embeds, self-verifies, and rejects external payload paths'
}
finally {
    if (Test-Path -LiteralPath $fixtureRoot) {
        $resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
        $resolvedFixture = [IO.Path]::GetFullPath($fixtureRoot)
        if (-not $resolvedFixture.StartsWith($resolvedTemp, [StringComparison]::OrdinalIgnoreCase) -or
            -not ([IO.Path]::GetFileName($resolvedFixture)).StartsWith('cus-embedded-setup-', [StringComparison]::Ordinal)) {
            throw 'Refusing to clean an unexpected embedded setup fixture path.'
        }
        Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
    }
}
