# v0.3.3 Windows Release Chain Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the permanently failing v0.3.3 setup placeholder with a complete, fail-closed Windows release build and verification chain.

**Architecture:** Keep the established v0.3.2 release build as the reference implementation. Add v0.3.3-specific immutable profile, evidence validation, manifest generation, payload verification, setup verification, and script tests. The full build runs only after a complete real-device evidence JSON, a P-256 SPKI public key, and an HTTPS update URI are supplied; missing or malformed inputs fail before artifact creation.

**Tech Stack:** PowerShell 7, Python 3 standard library, .NET 8 Windows projects, existing installer payload verifier.

**Spec:** `docs/superpowers/plans/2026-08-23-windows-compatibility-v033.md`

## Global Constraints

- Preserve historical v0.3.2 scripts unchanged.
- Release branch is exactly `v0.3.3`; artifact is `codex-usage-sidebar-v0.3.3-windows-x64-setup.exe`.
- Formal release accepts only complete Windows 11 AMD64 evidence for the packaged source commit.
- Never commit an ECDSA private key; build accepts only Base64 P-256 SPKI public key and HTTPS URI.
- Missing evidence must keep output non-publishable and must not create a setup artifact.

---

### Task 1: Add v0.3.3 evidence and release-script contract tests

**Files:**

- Create: `tests/test-windows-v033-release-chain.sh`
- Create: `scripts/v033_release_profiles.py`
- Test: `tests/test-windows-v033-release-chain.sh`

**Interfaces:**

- Consumes: `scripts/build-windows-v033-setup.ps1 -PlanOnly`.
- Produces: a reproducible contract that requires valid key/URI inputs and verifies the build script reaches source/evidence validation rather than an unconditional placeholder failure.

- [ ] **Step 1: Write failing script-contract tests**

```bash
pwsh -File scripts/build-windows-v033-setup.ps1 -PlanOnly
# Assert version 0.3.3, x64, schema-v2 selectors, and a non-publishable plan.

pwsh -File scripts/build-windows-v033-setup.ps1 \
  -ValidationEvidence "$tmp/evidence.json" -OutputDirectory "$tmp/out" \
  -CompatibilityPublicKey "$valid_spki" -CompatibilityUpdateUri https://example.invalid/pack.zip
# Assert failure is source/evidence validation, never the permanent Task 6 placeholder.
```

- [ ] **Step 2: Run the contract test and verify RED**

Run: `bash tests/test-windows-v033-release-chain.sh`

Expected: FAIL because the current v0.3.3 script always emits the permanent Task 6 gate and there are no v0.3.3 release descriptors.

- [ ] **Step 3: Implement only immutable v0.3.3 release profile metadata**

```python
FORMAL = MappingProxyType({
    "releaseProfile": "formal",
    "tag": "v0.3.3",
    "evidencePath": "docs/validation/windows-v0.3.3.json",
    "realDeviceValidated": True,
})
```

- [ ] **Step 4: Re-run contract tests**

Run: `bash tests/test-windows-v033-release-chain.sh`

Expected: still FAIL at the absent build/evidence chain, proving the test reaches the intended next boundary.

- [ ] **Step 5: Commit**

```bash
git add tests/test-windows-v033-release-chain.sh scripts/v033_release_profiles.py
git commit -m "test: define v0.3.3 release chain contract"
```

### Task 2: Implement strict v0.3.3 real-device evidence validation

**Files:**

- Create: `scripts/windows_v033_validation.py`
- Create: `scripts/verify-windows-v033-validation.py`
- Create: `docs/validation/windows-v0.3.3.schema.json`
- Modify: `tests/test-windows-v033-release-chain.sh`

**Interfaces:**

- Consumes: JSON with `schemaVersion`, `version`, `sourceCommit`, `architecture`, `windowsBuild`, `codexFileBuild`, `completedAt`, and `cases`.
- Produces: exit 0 only when all required v0.3.3 real-device matrix cases are unique and `pass`.

- [ ] **Step 1: Add failing valid/invalid JSON fixtures inside the test script**

```bash
python scripts/verify-windows-v033-validation.py "$tmp/incomplete.json" --source-commit "$commit"
# Assert nonzero for one missing required case.
python scripts/verify-windows-v033-validation.py "$tmp/complete.json" --source-commit "$commit"
# Assert zero for the complete, privacy-safe matrix.
```

- [ ] **Step 2: Run and verify RED**

Run: `bash tests/test-windows-v033-release-chain.sh`

Expected: fail because the validator/schema do not exist.

- [ ] **Step 3: Define exact case names and validator**

```python
VISUAL_LAYOUTS = ("wide", "narrow", "right-pane")
SCALES = (100, 125, 150, 200)
THEMES = ("light", "dark", "system")
LANGUAGES = ("en", "zh-CN")
GEOMETRY = ("restored", "maximized", "fullscreen")
INTERACTION = ("safe-dock-drag-snap", "safe-dock-lock-reset", "three-success-recovery")
LIFECYCLE = ("codex-restart-update", "sleep-resume", "app-server-recovery", "install-repair", "upgrade-retains-preferences", "uninstall", "package-provenance")
```

- [ ] **Step 4: Run and verify GREEN**

Run: `bash tests/test-windows-v033-release-chain.sh`

Expected: valid fixture passes; incomplete, duplicate, invalid build/version, and non-pass cases fail.

- [ ] **Step 5: Commit**

```bash
git add scripts/windows_v033_validation.py scripts/verify-windows-v033-validation.py docs/validation/windows-v0.3.3.schema.json tests/test-windows-v033-release-chain.sh
git commit -m "feat: validate v0.3.3 Windows device evidence"
```

### Task 3: Restore complete v0.3.3 payload, setup, and candidate verification

**Files:**

- Create: `scripts/build-windows-v033-release-manifest.py`
- Create: `scripts/verify-windows-v033-release-payload.py`
- Modify: `scripts/build-windows-v033-setup.ps1`, `scripts/verify-windows-v033-setup.ps1`, `tests/test-windows-v033-release-chain.sh`

**Interfaces:**

- Consumes: complete evidence JSON, source commit, public key, HTTPS URI, x64 payload.
- Produces: verified `compatibility-update.json`, `windows-payload.json`, setup executable, SHA-256 file, and v0.3.3 provenance.

- [ ] **Step 1: Add failing script test for a valid-input path that reaches branch/source validation**

```bash
pwsh -File scripts/build-windows-v033-setup.ps1 \
  -ValidationEvidence "$tmp/complete.json" -OutputDirectory "$tmp/out" \
  -CompatibilityPublicKey "$valid_spki" -CompatibilityUpdateUri https://example.invalid/pack.zip
# Assert no output contains “remains gated”; assert expected branch/source gate failure instead.
```

- [ ] **Step 2: Run and verify RED**

Run: `bash tests/test-windows-v033-release-chain.sh`

Expected: fail because v0.3.3 setup currently unconditionally throws after configuration validation.

- [ ] **Step 3: Port the complete v0.3.2 pattern with v0.3.3 identifiers**

```powershell
$compatibilityConfiguration = [ordered]@{
    schemaVersion = 1
    publicKey = $CompatibilityPublicKey
    updateUri = $CompatibilityUpdateUri
}
[IO.File]::WriteAllText((Join-Path $payload 'compatibility-update.json'),
    ($compatibilityConfiguration | ConvertTo-Json -Depth 3) + [Environment]::NewLine,
    [Text.UTF8Encoding]::new($false))
```

Require the payload manifest/installer required-file set to bind this configuration. Use v0.3.3 evidence validator in manifest generation and verification. Preserve atomic staging, checksum, provenance, embedded verification, branch/clean-worktree, runtime digest, and output-path safety checks from v0.3.2.

- [ ] **Step 4: Run and verify GREEN**

Run: `bash tests/test-windows-v033-release-chain.sh`

Expected: valid-input test reaches source/branch validation; invalid key, non-HTTPS URI, incomplete evidence, and non-v0.3.3 payload are rejected; no unconditional placeholder remains.

- [ ] **Step 5: Commit**

```bash
git add scripts/build-windows-v033-setup.ps1 scripts/verify-windows-v033-setup.ps1 scripts/build-windows-v033-release-manifest.py scripts/verify-windows-v033-release-payload.py tests/test-windows-v033-release-chain.sh
git commit -m "feat: restore v0.3.3 Windows release chain"
```

### Task 4: Document the formal release handoff and run verification

**Files:**

- Modify: `docs/validation/windows-v0.3.3-real-device-template.md`, `docs/INSTALL.md`, `docs/TROUBLESHOOTING.md`
- Test: `tests/test-windows-v033-release-chain.sh`, Windows solution tests

**Interfaces:**

- Consumes: task 1–3 release contracts.
- Produces: an exact maintainer handoff that lists evidence JSON, public key, update URI, branch and formal build command without exposing a private key.

- [ ] **Step 1: Add failing documentation-contract assertions**

```bash
rg 'CompatibilityPublicKey|CompatibilityUpdateUri|windows-v0.3.3.json' docs/validation/windows-v0.3.3-real-device-template.md
```

- [ ] **Step 2: Run and verify RED**

Run: `bash tests/test-windows-v033-release-chain.sh`

Expected: fail before the formal build handoff is documented.

- [ ] **Step 3: Add exact formal handoff command and non-fabrication statement**

```powershell
pwsh scripts/build-windows-v033-setup.ps1 \
  -ValidationEvidence docs/validation/windows-v0.3.3.json \
  -OutputDirectory <outside-repository-output> \
  -CompatibilityPublicKey <base64-p256-spki> \
  -CompatibilityUpdateUri <https-compatibility-pack-uri>
```

- [ ] **Step 4: Run full automatic verification**

Run: `bash tests/test-windows-v033-release-chain.sh`

Run: `dotnet test plugins/codex-usage-sidebar/windows/CodexUsageSidebar.Windows.sln --configuration Release --nologo`

Run: `git diff --check`

Expected: all automatic checks pass; setup remains blocked only when a maintainer has not supplied complete evidence and release inputs.

- [ ] **Step 5: Commit**

```bash
git add docs/validation/windows-v0.3.3-real-device-template.md docs/INSTALL.md docs/TROUBLESHOOTING.md tests/test-windows-v033-release-chain.sh
git commit -m "docs: hand off v0.3.3 Windows release gate"
```

## Self-review

- Spec coverage: Tasks 1–3 replace the permanent blocker with a full source-to-candidate chain; Task 2 enforces the complete manual matrix; Task 4 gives maintainers the exact non-secret inputs and command.
- Placeholder scan: no task relies on a later unspecified implementation; every release input and validation boundary is named.
- Type consistency: evidence is JSON throughout; all scripts consume the same source commit, x64 architecture, P-256 SPKI public key, and HTTPS URI.
