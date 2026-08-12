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

Export-ModuleMember -Function ConvertTo-WindowsProcessArgument, Join-WindowsProcessArguments
