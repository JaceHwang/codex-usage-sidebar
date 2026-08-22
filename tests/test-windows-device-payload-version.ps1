$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$plan = & (Join-Path $repoRoot 'scripts\install-windows-device-payload.ps1') -PlanOnly | ConvertFrom-Json
if ($plan.version -ne '0.3.1') {
    throw "Device-test installer plan must use runtime version 0.3.1, found $($plan.version)."
}

$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('cus-device-version-' + [Guid]::NewGuid().ToString('N'))
$payload = Join-Path $fixtureRoot 'payload'
New-Item -ItemType Directory -Force -Path $payload | Out-Null
try {
    foreach ($name in @('CodexUsageSidebar.Windows.exe', 'CodexUsageSidebar.Control.exe', 'codex.exe')) {
        [IO.File]::WriteAllText((Join-Path $payload $name), $name)
    }
    [IO.File]::WriteAllText((Join-Path $payload 'selectors.json'), '{"schemaVersion":1,"builds":[]}')
    $runtimeSha = (Get-FileHash -LiteralPath (Join-Path $payload 'codex.exe') -Algorithm SHA256).Hash.ToLowerInvariant()
    $sourceCommit = '0123456789abcdef0123456789abcdef01234567'
    $codexSource = 'https://github.com/openai/codex/releases/download/rust-v0.147.0/codex-x86_64-pc-windows-msvc.exe'
    & python (Join-Path $repoRoot 'scripts\build-windows-payload-manifest.py') `
        --payload-dir $payload --version $plan.version --architecture x64 `
        --source-commit $sourceCommit --codex-source $codexSource --codex-sha256 $runtimeSha
    if ($LASTEXITCODE -ne 0) {
        throw 'The device-test manifest builder rejected the installer plan version.'
    }
    & python (Join-Path $repoRoot 'scripts\verify-windows-payload.py') $payload
    if ($LASTEXITCODE -ne 0) {
        throw 'The device-test manifest verifier rejected the installer plan version.'
    }
    Write-Output 'PASS: Windows device-test installer and manifest versions are aligned'
}
finally {
    if (Test-Path -LiteralPath $fixtureRoot) {
        Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
    }
}
