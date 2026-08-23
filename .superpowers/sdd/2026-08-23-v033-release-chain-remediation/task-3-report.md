# Task 3 Report: v0.3.3 Windows Release Chain

Implemented the v0.3.3 Windows payload and candidate release chain without changing the v0.3.2 scripts or Task 4 documentation.

- Added v0.3.3 manifest generation and payload verification, both consuming `scripts/v033_release_profiles.py` and validating complete v0.3.3 evidence.
- The setup builder accepts only Base64 P-256 SPKI public keys and HTTPS update URIs, emits `compatibility-update.json` with only `schemaVersion`, `publicKey`, and `updateUri`, and binds its SHA-256 in the payload manifest and candidate provenance.
- Replaced setup and candidate-verification placeholders with branch, clean-worktree, canonical-evidence, source-commit, runtime-digest, atomic-staging, checksum, provenance, and embedded-payload verification gates.
- Extended the release-chain contract to reject invalid compatibility inputs, incomplete evidence, malformed compatibility configuration, and non-v0.3.3 payloads.

Verification run:

```text
bash tests/test-windows-v033-release-chain.sh
python -m py_compile scripts/build-windows-v033-release-manifest.py scripts/verify-windows-v033-release-payload.py
git diff --check
```

The full release build remains fail-closed until a maintainer provides the tracked canonical `docs/validation/windows-v0.3.3.json` real-device evidence on the exact `v0.3.3` branch.
