function Assert-WindowsDeviceSourceState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $RepositoryRoot,
        [Parameter(Mandatory = $true)]
        [string[]] $BuildInputRoots
    )

    $root = [IO.Path]::GetFullPath($RepositoryRoot)
    $sourceCommit = (& git -C $root rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0 -or $sourceCommit -notmatch '^[0-9a-f]{40}$') {
        throw [InvalidOperationException]::new('Could not resolve the exact source commit.')
    }

    $status = @(& git -C $root status --porcelain=v1 --untracked-files=all)
    if ($LASTEXITCODE -ne 0) {
        throw [InvalidOperationException]::new('Could not inspect the Git working tree.')
    }
    if (($status -join '').Trim().Length -ne 0) {
        throw [InvalidOperationException]::new(
            'Commit or remove every tracked and untracked change before building a provenance-bound payload.')
    }

    foreach ($buildInputRoot in $BuildInputRoots) {
        if ([IO.Path]::IsPathRooted($buildInputRoot) -or
            $buildInputRoot.Replace('\', '/').Split('/') -contains '..') {
            throw [ArgumentException]::new('Build input roots must stay inside the repository.', 'BuildInputRoots')
        }
        $ignored = @(& git -C $root ls-files --others --ignored --exclude-standard -- $buildInputRoot)
        if ($LASTEXITCODE -ne 0) {
            throw [InvalidOperationException]::new('Could not inspect ignored build inputs.')
        }
        $unsafeIgnored = @($ignored | Where-Object {
            $normalized = $_.Replace('\', '/')
            $normalized -and
                $normalized -notmatch '(^|/)(bin|obj)/' -and
                $normalized -notmatch '^\.dist/' -and
                $normalized -notmatch '^\.build/' -and
                $normalized -notmatch '^\.worktrees/' -and
                $normalized -notmatch '^\.superpowers/sdd(/|$)' -and
                $normalized -notmatch '^plugins/codex-usage-sidebar/native/\.build/' -and
                $normalized -notmatch '\.xcresult(/|$)' -and
                $normalized -notmatch '(^|/)\.DS_Store$'
        })
        if ($unsafeIgnored.Count -ne 0) {
            throw [InvalidOperationException]::new(
                'Ignored files can affect the device build: ' + ($unsafeIgnored -join ', '))
        }
    }

    return $sourceCommit
}

function Assert-WindowsDevicePlatform {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [bool] $IsWindows,
        [Parameter(Mandatory = $true)]
        [string] $Architecture,
        [Parameter(Mandatory = $true)]
        [int] $WindowsBuild
    )

    if (-not $IsWindows -or $Architecture -ne 'x64' -or $WindowsBuild -lt 22000) {
        throw [PlatformNotSupportedException]::new(
            'Windows v0.3.1 device payloads require Windows 11 AMD64/x64 build 22000 or newer.')
    }
}

function Wait-WindowsDeviceCondition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock] $Condition,
        [int] $TimeoutMilliseconds = 5000,
        [int] $PollMilliseconds = 100
    )

    if ($TimeoutMilliseconds -le 0 -or $PollMilliseconds -le 0) {
        throw [ArgumentOutOfRangeException]::new('Timeout and poll intervals must be positive.')
    }
    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        $result = & $Condition
        if ($null -ne $result -and $result -ne $false) {
            return $result
        }
        if ($stopwatch.ElapsedMilliseconds -ge $TimeoutMilliseconds) {
            throw [TimeoutException]::new(
                "The device condition was not satisfied within $TimeoutMilliseconds milliseconds.")
        }
        Start-Sleep -Milliseconds $PollMilliseconds
    }
}

function Copy-WindowsDeviceRuntimeFromCache {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]] $Candidates,
        [Parameter(Mandatory = $true)]
        [string] $Destination,
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[0-9a-fA-F]{64}$')]
        [string] $ExpectedSha256
    )

    $expected = $ExpectedSha256.ToLowerInvariant()
    foreach ($candidate in $Candidates) {
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            continue
        }
        $candidateSha256 = (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($candidateSha256 -ne $expected) {
            continue
        }
        Copy-Item -LiteralPath $candidate -Destination $Destination -Force
        $destinationSha256 = (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($destinationSha256 -ne $expected) {
            Remove-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
            throw [IO.InvalidDataException]::new('The copied device runtime does not match the pinned digest.')
        }
        return $true
    }
    return $false
}

function New-WindowsV033HostControlPublishProperties {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Framework,
        [Parameter(Mandatory = $true)]
        [string] $RuntimeIdentifier,
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[0-9a-f]{40}$')]
        [string] $SourceCommit,
        [Parameter(Mandatory = $true)]
        [string] $CompatibilityPublicKey,
        [Parameter(Mandatory = $true)]
        [string] $CompatibilityUpdateUri
    )

    return @(
        '--configuration', 'Release', '--framework', $Framework, '--runtime', $RuntimeIdentifier,
        '--self-contained', 'true', '-p:PublishTrimmed=false', '-p:DebugType=None',
        '-p:DebugSymbols=false', "-p:SourceRevisionId=$SourceCommit",
        "-p:CompatibilityPublicKey=$CompatibilityPublicKey",
        "-p:CompatibilityUpdateUri=$CompatibilityUpdateUri", '--nologo'
    )
}

function Enter-WindowsDeviceInstallLock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $LockPath
    )

    $resolvedLockPath = [IO.Path]::GetFullPath($LockPath)
    $parent = Split-Path -Parent $resolvedLockPath
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    return [IO.File]::Open(
        $resolvedLockPath,
        [IO.FileMode]::OpenOrCreate,
        [IO.FileAccess]::ReadWrite,
        [IO.FileShare]::None)
}

function New-WindowsDeviceSelectorsDocument {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateCount(3, 3)]
        [string[]] $FixturePaths
    )

    $builds = foreach ($fixturePath in $FixturePaths) {
        if (-not (Test-Path -LiteralPath $fixturePath -PathType Leaf)) {
            throw [IO.FileNotFoundException]::new('A pinned Windows UIA fixture is missing.', $fixturePath)
        }
        $fixtureName = [IO.Path]::GetFileName($fixturePath)
        $match = [regex]::Match(
            $fixtureName,
            '^windows-codex-(?<build>\d+\.\d+\.\d+\.\d+)-(?<layout>default|default-flat|narrow)-200\.json$')
        if (-not $match.Success) {
            throw [IO.InvalidDataException]::new('The Windows UIA fixture name is not recognized.')
        }
        $fixture = Get-Content -Raw -LiteralPath $fixturePath | ConvertFrom-Json
        if ($fixture.schemaVersion -ne 3 -or
            $fixture.buildIdentity -cne $match.Groups['build'].Value -or
            $fixture.sourceReportSha256 -notmatch '^[0-9a-f]{64}$') {
            throw [IO.InvalidDataException]::new('The Windows UIA fixture provenance is invalid.')
        }
        [pscustomobject][ordered]@{
            buildIdentity = $fixture.buildIdentity
            layout = switch ($match.Groups['layout'].Value) {
                'default' { 'wide' }
                'default-flat' { 'wide-flat' }
                default { 'narrow' }
            }
            fixture = $fixtureName
            sourceReportSha256 = $fixture.sourceReportSha256
        }
    }
    $layouts = @($builds | Select-Object -ExpandProperty layout | Sort-Object)
    if ($layouts.Count -ne 3 -or
        ($layouts -join ',') -cne 'narrow,wide,wide-flat' -or
        @($builds | Select-Object -ExpandProperty buildIdentity -Unique).Count -ne 1) {
        throw [IO.InvalidDataException]::new('The selector document requires one wrapped-wide, one flat-wide, and one narrow fixture for the same Codex build.')
    }

    return [pscustomobject][ordered]@{
        schemaVersion = 1
        status = 'device-test'
        realDeviceValidated = $false
        publishableInstaller = $false
        builds = @($builds | Sort-Object layout -Descending)
    }
}

Export-ModuleMember -Function Assert-WindowsDeviceSourceState, Assert-WindowsDevicePlatform, Wait-WindowsDeviceCondition, Copy-WindowsDeviceRuntimeFromCache, New-WindowsV033HostControlPublishProperties, Enter-WindowsDeviceInstallLock, New-WindowsDeviceSelectorsDocument
