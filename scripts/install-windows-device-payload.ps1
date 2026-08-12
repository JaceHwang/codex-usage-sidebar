[CmdletBinding()]
param(
    [switch] $PlanOnly,
    [switch] $BuildOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$version = '0.3.0-beta.1'
$architecture = 'x64'
$runtimeIdentifier = 'win-x64'
$codexRuntimeSource = 'https://github.com/openai/codex/releases/download/rust-v0.147.0/codex-x86_64-pc-windows-msvc.exe'
$codexRuntimeSha256 = '935a1911ed2556e4ffcec995f4886ac2ac425863ba26fed264df62e30272ad9d'
$installTarget = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)) 'CodexUsageSidebar\Current'

$plan = [ordered]@{
    schemaVersion = 1
    status = 'device-test'
    version = $version
    architecture = $architecture
    runtimeIdentifier = $runtimeIdentifier
    minimumWindowsBuild = 22000
    hostControlSingleFile = $false
    artifactName = "codex-usage-sidebar-$version-windows-x64-device-test"
    installTarget = $installTarget
    codexRuntime = [ordered]@{
        source = $codexRuntimeSource
        sha256 = $codexRuntimeSha256
    }
    realDeviceValidated = $false
    publishableInstaller = $false
}

if ($PlanOnly) {
    $plan | ConvertTo-Json -Depth 4
    exit 0
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $PSScriptRoot 'WindowsDevicePayload.Source.psm1') -Force
Assert-WindowsDevicePlatform `
    -IsWindows ([Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([Runtime.InteropServices.OSPlatform]::Windows)) `
    -Architecture ([Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString().ToLowerInvariant()) `
    -WindowsBuild ([Environment]::OSVersion.Version.Build)
$sourceCommit = Assert-WindowsDeviceSourceState -RepositoryRoot $repoRoot -BuildInputRoots @('.')

$distRoot = Join-Path $repoRoot '.dist\windows-device-test'
$payload = Join-Path $distRoot $sourceCommit
$operationRoot = Join-Path $distRoot ('.stage-' + [Guid]::NewGuid().ToString('N'))
$installerOutput = Join-Path $operationRoot 'installer'
$stagedPayload = Join-Path $operationRoot 'payload'
New-Item -ItemType Directory -Force -Path $installerOutput, $stagedPayload | Out-Null

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
        '--nologo'
    )
    $controlProject = Join-Path $repoRoot 'plugins\codex-usage-sidebar\windows\src\CodexUsageSidebar.Control\CodexUsageSidebar.Control.csproj'
    $manifestBuilder = Join-Path $repoRoot 'scripts\build-windows-payload-manifest.py'
    $manifestVerifier = Join-Path $repoRoot 'scripts\verify-windows-payload.py'
    if (Test-Path -LiteralPath $payload) {
        & python $manifestVerifier $payload
        if ($LASTEXITCODE -ne 0) { throw 'The existing deterministic device payload is invalid.' }
        $existingManifest = Get-Content -Raw -LiteralPath (Join-Path $payload 'windows-payload.json') | ConvertFrom-Json
        if ($existingManifest.sourceCommit -ne $sourceCommit -or
            $existingManifest.codexRuntime.source -ne $codexRuntimeSource -or
            $existingManifest.codexRuntime.sha256 -ne $codexRuntimeSha256) {
            throw 'The existing deterministic device payload has a different provenance identity.'
        }
        $actualRuntimeSha256 = (Get-FileHash -LiteralPath (Join-Path $payload 'codex.exe') -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    else {
        & dotnet publish $controlProject @commonPublishProperties `
            '-p:PublishSingleFile=false' --output $stagedPayload
        if ($LASTEXITCODE -ne 0) { throw 'The Windows Host/Control publish failed.' }
        if (-not (Test-Path -LiteralPath (Join-Path $stagedPayload 'CodexUsageSidebar.Windows.exe')) -or
            -not (Test-Path -LiteralPath (Join-Path $stagedPayload 'CodexUsageSidebar.Control.exe'))) {
            throw 'The Windows Host/Control publish is incomplete.'
        }
        $smokeReport = Join-Path $operationRoot 'uia-smoke.json'
        & (Join-Path $stagedPayload 'CodexUsageSidebar.Control.exe') probe $smokeReport
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $smokeReport)) {
            throw 'The default-redacted Windows UI Automation smoke probe failed.'
        }

        $runtimePath = Join-Path $stagedPayload 'codex.exe'
        Invoke-WebRequest -Uri $codexRuntimeSource -OutFile $runtimePath -UseBasicParsing
        $actualRuntimeSha256 = (Get-FileHash -LiteralPath $runtimePath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualRuntimeSha256 -ne $codexRuntimeSha256) {
            throw "The downloaded Codex x64 runtime digest is invalid: $actualRuntimeSha256"
        }

        $selectorsJson = [ordered]@{
            schemaVersion = 1
            status = 'device-test'
            realDeviceValidated = $false
            publishableInstaller = $false
            builds = @(
                [ordered]@{
                    buildIdentity = '151.0.7922.76'
                    fixture = 'windows-codex-151.0.7922.76-default-200.json'
                    sourceReportSha256 = '51f4ce5235996b6a9f04139b104446ce76dd6a552b8ea6cc9f2adcc34d5eda59'
                }
            )
        } | ConvertTo-Json -Depth 5
        [IO.File]::WriteAllText(
            (Join-Path $stagedPayload 'selectors.json'),
            $selectorsJson + [Environment]::NewLine,
            [Text.UTF8Encoding]::new($false))

        & python $manifestBuilder --payload-dir $stagedPayload --version $version --architecture $architecture `
            --source-commit $sourceCommit --codex-source $codexRuntimeSource --codex-sha256 $codexRuntimeSha256
        if ($LASTEXITCODE -ne 0) { throw 'The Windows device payload manifest build failed.' }
        & python $manifestVerifier $stagedPayload
        if ($LASTEXITCODE -ne 0) { throw 'The Windows device payload verification failed.' }

        New-Item -ItemType Directory -Force -Path $distRoot | Out-Null
        Move-Item -LiteralPath $stagedPayload -Destination $payload
    }

    $manifestSha256 = (Get-FileHash -LiteralPath (Join-Path $payload 'windows-payload.json') -Algorithm SHA256).Hash.ToLowerInvariant()

    if (-not $BuildOnly) {
        $managedRuntime = Join-Path $installTarget 'CodexUsageSidebar.Windows.exe'
        Get-CimInstance Win32_Process -Filter "Name = 'CodexUsageSidebar.Windows.exe'" -ErrorAction SilentlyContinue |
            Where-Object { $_.ExecutablePath -and ([IO.Path]::GetFullPath($_.ExecutablePath) -eq [IO.Path]::GetFullPath($managedRuntime)) } |
            ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction Stop }

        $installerProject = Join-Path $repoRoot 'plugins\codex-usage-sidebar\windows\src\CodexUsageSidebar.Installer\CodexUsageSidebar.Installer.csproj'
        & dotnet publish $installerProject @commonPublishProperties `
            '-p:PublishSingleFile=true' `
            "-p:DeviceSourceCommit=$sourceCommit" `
            "-p:DevicePayloadManifestSha256=$manifestSha256" `
            --output $installerOutput
        if ($LASTEXITCODE -ne 0) { throw 'The provenance-bound device installer helper publish failed.' }
        $installer = Join-Path $installerOutput 'CodexUsageSidebar.Installer.exe'
        & $installer --device-install $payload
        if ($LASTEXITCODE -ne 0) { throw "The atomic device payload installation failed with exit code $LASTEXITCODE." }

        $controlScript = Join-Path $repoRoot 'plugins\codex-usage-sidebar\scripts\sidebar-control-windows.ps1'
        & $controlScript ensure -PluginRoot (Join-Path $repoRoot 'plugins\codex-usage-sidebar')
        if ($LASTEXITCODE -ne 0) { throw 'The Windows overlay host did not start.' }
        Start-Sleep -Milliseconds 750
        $runtimeStatus = (& $controlScript status | Out-String).Trim()
        if ($LASTEXITCODE -ne 0 -or $runtimeStatus -notmatch '^runtime=running pid=\d+ version=0\.3\.0-beta\.1$') {
            throw "The Windows overlay host is not running: $runtimeStatus"
        }
        Write-Output $runtimeStatus
    }

    [ordered]@{
        payload = $payload
        installTarget = $installTarget
        sourceCommit = $sourceCommit
        payloadManifestSha256 = $manifestSha256
        runtimeSha256 = $actualRuntimeSha256
        installed = -not $BuildOnly
        publishableInstaller = $false
    } | ConvertTo-Json -Depth 3
}
finally {
    if (Test-Path -LiteralPath $operationRoot) {
        $resolvedDistRoot = [IO.Path]::GetFullPath($distRoot).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
        $resolvedOperationRoot = [IO.Path]::GetFullPath($operationRoot)
        if (-not $resolvedOperationRoot.StartsWith($resolvedDistRoot, [StringComparison]::OrdinalIgnoreCase) -or
            -not ([IO.Path]::GetFileName($resolvedOperationRoot)).StartsWith('.stage-', [StringComparison]::Ordinal)) {
            throw 'Refusing to clean an unexpected device payload staging path.'
        }
        Remove-Item -LiteralPath $operationRoot -Recurse -Force
    }
}
