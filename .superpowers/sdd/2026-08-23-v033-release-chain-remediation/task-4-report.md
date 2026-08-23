# Task 4 Report: v0.3.3 Formal Release Handoff

Task 4 adds the maintainer handoff for the fail-closed v0.3.3 Windows release chain. It does not
publish an installer or claim formal Windows device validation.

Changed paths:

- `docs/validation/windows-v0.3.3-real-device-template.md`
- `docs/INSTALL.md`
- `docs/TROUBLESHOOTING.md`
- `tests/test-windows-v033-release-chain.sh`
- `.superpowers/sdd/2026-08-23-v033-release-chain-remediation/progress.md`

TDD proof:

```text
$ bash tests/test-windows-v033-release-chain.sh
AssertionError: missing v0.3.3 documentation contract: canonical formal evidence path
```

The focused contract was added before the documentation. It requires the canonical evidence path,
outside-repository output, Base64 P-256 SPKI public-key input, HTTPS compatibility-pack URI,
private-key boundary, exact branch/clean-worktree/source-commit requirements, the unpublished
installer status, and ordinary-user recovery guidance.

Verification:

```text
$ bash tests/test-windows-v033-release-chain.sh
PASS: Windows v0.3.3 full-chain reaches the branch/source validation boundary

$ dotnet test plugins/codex-usage-sidebar/windows/CodexUsageSidebar.Windows.sln --configuration Release --nologo
Passed: 262, Failed: 0, Skipped: 0

$ git diff --check
(exit 0)
```

The formal build remains unavailable until a maintainer supplies committed canonical evidence for a
complete Windows 11 AMD64/x64 real-device matrix tied to the packaging source commit, runs from the
exact `v0.3.3` branch with a clean worktree, and provides the public key and HTTPS update URI.
