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

Export-ModuleMember -Function Assert-WindowsDeviceSourceState
