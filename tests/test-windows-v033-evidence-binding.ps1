$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$modulePath = Join-Path $PSScriptRoot '..\scripts\WindowsDevicePayload.Source.psm1'
Import-Module $modulePath -Force

$root = Join-Path ([IO.Path]::GetTempPath()) ('v033-evidence-binding-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $root | Out-Null
try {
    & git -C $root init --quiet
    & git -C $root config user.email 'test@example.invalid'
    & git -C $root config user.name 'v0.3.3 test'
    [IO.File]::WriteAllText((Join-Path $root 'source.txt'), 'tested source')
    & git -C $root add source.txt
    & git -C $root commit --quiet -m source
    $sourceCommit = (& git -C $root rev-parse HEAD).Trim()

    $evidenceRelative = 'docs/validation/windows-v0.3.3.json'
    $evidencePath = Join-Path $root $evidenceRelative
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $evidencePath) | Out-Null
    [IO.File]::WriteAllText($evidencePath, ('{"sourceCommit":"' + $sourceCommit + '"}'))
    & git -C $root add -- $evidenceRelative
    & git -C $root commit --quiet -m evidence
    $packagingCommit = (& git -C $root rev-parse HEAD).Trim()
    if ($packagingCommit -eq $sourceCommit) { throw 'The evidence fixture did not create a second commit.' }

    $resolved = Assert-WindowsV033EvidenceSourceState `
        -RepositoryRoot $root `
        -EvidenceRelativePath $evidenceRelative `
        -SourceCommit $sourceCommit
    if ($resolved -ne $packagingCommit) {
        throw "Expected packaging commit $packagingCommit, got $resolved."
    }

    [IO.File]::WriteAllText((Join-Path $root 'source.txt'), 'unreviewed source change')
    & git -C $root add source.txt
    & git -C $root commit --quiet -m 'unreviewed source change'
    try {
        Assert-WindowsV033EvidenceSourceState -ErrorAction Stop `
            -RepositoryRoot $root `
            -EvidenceRelativePath $evidenceRelative `
            -SourceCommit $sourceCommit | Out-Null
        throw 'The evidence binding accepted a code change after validation.'
    } catch {
        if ($_.Exception.Message -eq 'The evidence binding accepted a code change after validation.') {
            throw
        }
    }

    Write-Output 'PASS: v0.3.3 evidence binds a tested source commit to an evidence-only packaging commit'
} finally {
    if (Test-Path -LiteralPath $root) {
        Remove-Item -LiteralPath $root -Recurse -Force
    }
}
