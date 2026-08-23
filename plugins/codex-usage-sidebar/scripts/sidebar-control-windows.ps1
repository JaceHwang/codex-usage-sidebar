[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('ensure', 'status', 'diagnostic')]
    [string] $Command,
    [string] $PluginRoot,
    [string] $PluginData,
    [string] $OutputPath,
    [switch] $IncludeText
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'WindowsProcessCommandLine.psm1') -Force

$localAppData = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
$installRoot = [IO.Path]::GetFullPath((Join-Path $localAppData 'CodexUsageSidebar'))
$current = [IO.Path]::GetFullPath((Join-Path $installRoot 'Current'))
$runtime = [IO.Path]::GetFullPath((Join-Path $current 'CodexUsageSidebar.Windows.exe'))
$control = [IO.Path]::GetFullPath((Join-Path $current 'CodexUsageSidebar.Control.exe'))
$selectors = [IO.Path]::GetFullPath((Join-Path $current 'selectors.json'))
$installLock = [IO.Path]::GetFullPath((Join-Path $installRoot 'install.lock'))

function Get-ManagedProcess {
    if (-not (Test-Path -LiteralPath $runtime -PathType Leaf)) {
        return $null
    }
    $expected = $runtime
    return Get-CimInstance Win32_Process -Filter "Name = 'CodexUsageSidebar.Windows.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.ExecutablePath -and ([IO.Path]::GetFullPath($_.ExecutablePath) -eq $expected) } |
        Select-Object -First 1
}

switch ($Command) {
    'ensure' {
        if (Test-WindowsSidebarInstallInProgress -LockPath $installLock) {
            exit 0
        }
        if (-not (Test-Path -LiteralPath $runtime -PathType Leaf) -or
            -not (Test-Path -LiteralPath $selectors -PathType Leaf)) {
            Write-Output 'runtime=unavailable reason=install-required version=0.3.3'
            exit 20
        }
        if (Get-ManagedProcess) {
            exit 0
        }
        $start = [Diagnostics.ProcessStartInfo]::new()
        $start.FileName = $runtime
        $start.UseShellExecute = $false
        $start.CreateNoWindow = $true
        $runtimeArguments = @('--background')
        if ($PluginRoot) {
            $runtimeArguments += '--plugin-root'
            $runtimeArguments += [IO.Path]::GetFullPath($PluginRoot)
        }
        if ($PluginData) {
            $runtimeArguments += '--plugin-data'
            $runtimeArguments += [IO.Path]::GetFullPath($PluginData)
        }
        if ($null -ne $start.PSObject.Properties['ArgumentList']) {
            foreach ($argument in $runtimeArguments) {
                $start.ArgumentList.Add($argument)
            }
        }
        else {
            $start.Arguments = Join-WindowsProcessArguments -Arguments $runtimeArguments
        }
        $process = [Diagnostics.Process]::Start($start)
        if ($null -eq $process) {
            throw 'Windows sidebar runtime did not start.'
        }
        $process.Dispose()
        exit 0
    }
    'status' {
        $managed = Get-ManagedProcess
        if ($managed) {
            if (Test-Path -LiteralPath $control -PathType Leaf) {
                & $control status
            }
            else {
                Write-Output 'runtime=running state=unknown'
            }
            exit 0
        }
        if (-not (Test-Path -LiteralPath $runtime -PathType Leaf)) {
            Write-Output 'runtime=unavailable reason=payload-not-installed version=0.3.3'
            exit 0
        }
        Write-Output 'runtime=stopped reason=not-running version=0.3.3'
        exit 0
    }
    'diagnostic' {
        if (-not $OutputPath) {
            throw 'diagnostic requires -OutputPath.'
        }
        if (-not (Test-Path -LiteralPath $control -PathType Leaf)) {
            throw 'CodexUsageSidebar.Control.exe is not installed.'
        }
        if ($IncludeText) { throw 'Diagnostic export never includes raw UI text.' }
        $arguments = @('diagnostic', [IO.Path]::GetFullPath($OutputPath))
        & $control @arguments
        exit $LASTEXITCODE
    }
}
