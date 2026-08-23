# Task 1 report: v0.3.3 release-chain remediation

## Scope

Implemented only Task 1. Added the Bash contract test and the immutable v0.3.3 formal release profile metadata. The existing v0.3.3 build script and all v0.3.2 files were left unchanged. Tasks 2–4 were not implemented.

## RED evidence

1. Initial contract run, before the profile existed:

   `bash tests/test-windows-v033-release-chain.sh`

   Result: `exit_code=1`; after making the Windows PowerShell runtime available to the WSL Bash harness, the test failed with:

   `FileNotFoundError: .../scripts/v033_release_profiles.py`

   This was the expected missing-descriptor RED state.

2. Contract run after adding only `scripts/v033_release_profiles.py`:

   `bash tests/test-windows-v033-release-chain.sh`

   Result: `exit_code=1`, with:

   `v0.3.3 build still fails at the permanent Task 6 placeholder`

   The test used a valid P-256 SPKI public key, HTTPS update URI, and missing evidence path. The build therefore passed key/URI validation and reached the existing Task 6 gate. No Task 2–4 behavior was added.

## GREEN evidence

The metadata-only contract passes:

`python -c 'import importlib.util, pathlib; p=pathlib.Path("scripts/v033_release_profiles.py"); s=importlib.util.spec_from_file_location("v033", p); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); assert m.FORMAL["tag"]=="v0.3.3"; assert m.FORMAL["realDeviceValidated"] is True; print("PASS: v0.3.3 formal profile metadata contract")'`

Result: `exit_code=0`; `PASS: v0.3.3 formal profile metadata contract`.

The full release-chain contract intentionally remains RED at the absent later build/evidence chain, as required by the Task 1 brief.

## Changed files

- `tests/test-windows-v033-release-chain.sh`
- `scripts/v033_release_profiles.py`
- This report

## Concerns

- The full Task 1 contract is expected to remain failing until the later release-chain tasks replace the permanent Task 6 gate with source/evidence validation.
- The first direct Bash invocation could not resolve `pwsh` from WSL; evidence was captured using the available Windows PowerShell runtime through a temporary, untracked test-harness shim, which was removed afterward.
