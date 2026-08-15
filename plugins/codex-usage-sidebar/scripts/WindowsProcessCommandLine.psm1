function ConvertTo-WindowsProcessArgument {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string] $Argument
    )

    if ($Argument.Length -gt 0 -and $Argument -notmatch '[\s"]') {
        return $Argument
    }

    $builder = New-Object Text.StringBuilder
    [void] $builder.Append([char]34)
    $backslashes = 0
    foreach ($character in $Argument.ToCharArray()) {
        if ($character -eq [char]92) {
            $backslashes++
            continue
        }
        if ($character -eq [char]34) {
            [void] $builder.Append([char]92, (($backslashes * 2) + 1))
            [void] $builder.Append($character)
            $backslashes = 0
            continue
        }
        if ($backslashes -gt 0) {
            [void] $builder.Append([char]92, $backslashes)
            $backslashes = 0
        }
        [void] $builder.Append($character)
    }
    if ($backslashes -gt 0) {
        [void] $builder.Append([char]92, ($backslashes * 2))
    }
    [void] $builder.Append([char]34)
    return $builder.ToString()
}

function Join-WindowsProcessArguments {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]] $Arguments
    )

    $quoted = @($Arguments | ForEach-Object { ConvertTo-WindowsProcessArgument -Argument $_ })
    return [string]::Join(' ', $quoted)
}

function Test-WindowsSidebarInstallInProgress {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $LockPath
    )

    if (-not (Test-Path -LiteralPath $LockPath -PathType Leaf)) {
        return $false
    }
    try {
        $probe = [IO.File]::Open(
            $LockPath,
            [IO.FileMode]::Open,
            [IO.FileAccess]::ReadWrite,
            [IO.FileShare]::ReadWrite)
        $probe.Dispose()
        return $false
    }
    catch [IO.IOException] {
        return $true
    }
    catch [UnauthorizedAccessException] {
        return $true
    }
}

function Invoke-WindowsProcessAndWait {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $FileName,
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]] $Arguments
    )

    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = if ([IO.Path]::IsPathRooted($FileName)) {
        [IO.Path]::GetFullPath($FileName)
    }
    else {
        (Get-Command -Name $FileName -CommandType Application -ErrorAction Stop).Source
    }
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    if ($null -ne $start.PSObject.Properties['ArgumentList']) {
        foreach ($argument in $Arguments) {
            $start.ArgumentList.Add($argument)
        }
    }
    else {
        $start.Arguments = Join-WindowsProcessArguments -Arguments $Arguments
    }
    $process = [Diagnostics.Process]::Start($start)
    if ($null -eq $process) {
        throw [InvalidOperationException]::new('The Windows device process did not start.')
    }
    try {
        $process.WaitForExit()
        return $process.ExitCode
    }
    finally {
        $process.Dispose()
    }
}

Export-ModuleMember -Function ConvertTo-WindowsProcessArgument, Join-WindowsProcessArguments, Test-WindowsSidebarInstallInProgress, Invoke-WindowsProcessAndWait
