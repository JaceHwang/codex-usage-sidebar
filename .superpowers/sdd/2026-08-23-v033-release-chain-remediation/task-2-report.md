# Task 2 report: v0.3.3 real-device evidence validation

## Scope

Implemented only Task 2. Added privacy-safe complete and incomplete fixtures to the v0.3.3 release-chain test, the v0.3.3 schema, and a fail-closed validator. Historical v0.3.2 files and partial evidence were not modified. Tasks 3 and 4 were not implemented.

## RED evidence

With `scripts/verify-windows-v033-validation.py` temporarily withheld during the test (and restored immediately afterward), the required contract command failed as intended:

`bash tests/test-windows-v033-release-chain.sh`

Result: `exit_code=2`; Python reported that `scripts/verify-windows-v033-validation.py` did not exist. This demonstrates that the new fixture contract depends on the new validator rather than existing Task 1 behavior.

## GREEN evidence

After restoring the validator, the validation portion of the same contract produced:

- rejection for a matrix with one visual case missing;
- acceptance for the complete 85-case privacy-safe fixture;
- rejection for duplicate visual coverage, a Windows 10 build, version `0.3.2`, and a non-passing lifecycle case.

The full release-chain command then reaches the unchanged Task 3 boundary and exits nonzero because `build-windows-v033-setup.ps1` still emits its permanent Task 6 placeholder. No Task 3 change was made to bypass or replace that gate.

## Contract enforced

- exact v0.3.3/x64/schema/source-commit identity;
- Windows 11 build, four-part Codex file build, and UTC completion time;
- exactly 72 visual combinations (3 layouts × 4 scales × 3 themes × 2 languages);
- exact geometry, interaction, and lifecycle named cases;
- each case is unique and has `result: "pass"`;
- closed JSON shapes prevent free-text or device-identifying evidence fields.
