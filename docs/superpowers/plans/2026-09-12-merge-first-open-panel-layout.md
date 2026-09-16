# Merge first-open-panel-layout Implementation Plan

> Historical design/plan snapshot. For the implemented 0.4.0 candidate, use [current design](../../CURRENT_DESIGN.md) and [current features](../../CURRENT_FEATURES.md). This record is not the current behavior or release approval.

**Goal:** Merge the tracked contents of the user-specified plugin directory into this repository's `plugins/codex-usage-sidebar/`.

**Architecture:** Transfer the committed plugin snapshot from source commit `8c2ccc0`, preserving file modes and all destination-only content. Do not import the source repository's unrelated root workflows or rewrite release history.

**Tech Stack:** Swift/AppKit, C#/WPF, shell regression checks.

## Constraints

- Work on `codex/merge/first-open-panel-layout` in the requested current directory.
- Preserve the pre-existing `.gitignore` edit.
- Include source metadata and bundled assets without manually changing product versions.
- Do not copy ignored build outputs, caches, or source Git metadata.
- No commit, push, application installation, or release is requested.

## Tasks

- [x] Copy tracked plugin files after recording the before/after inventory outside the repository.
- [x] Verify every source plugin file matches destination bytes and executable mode; preserve destination-only files.
- [x] Run Swift tests and plugin shell checks. Run root checks to expose integration constraints, documenting any release metadata mismatch instead of weakening checks.
- [x] Record results and provide the changed-file summary and outstanding platform validation limits.

## Integration dependencies and verification

Imported five supporting files from the same source snapshot: `releases/platform-release-catalog.json`, `version.txt`, `.release-please-manifest.json`, `tests/test-repository-governance.sh`, and `docs/releases/macos-v0.4.0.md`. These satisfy the imported Windows hook test and synchronize existing candidate metadata. No release was created or product version invented.

- All 294 source tracked plugin files match destination bytes and permissions; 65 files were copied or restored.
- Swift package tests: 318 passed, zero failures.
- All five plugin shell checks passed after importing the release catalog.
- Repository governance integration test passed.
- Companion SHA-256 and strict code signature verification passed.
- Merged native files match the bundled companion's provenance source commit.
- `git diff --check` passed; the existing `.gitignore` change is preserved.
- Full public-repository validation remains unavailable on the uncommitted merge: it compares the provenance source commit with the old `HEAD`, rather than the working files. Local source history was fetched so the provenance commit is available. The validator was not bypassed or modified.
- Windows .NET/WPF tests were not run: no executable .NET or PowerShell runtime was found. No Windows runtime success is claimed.

The requested directory merge is complete and remains uncommitted. Publishing and Windows runtime validation are outside this directory-transfer result.
