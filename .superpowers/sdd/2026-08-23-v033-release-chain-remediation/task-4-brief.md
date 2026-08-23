### Task 4: Document the formal v0.3.3 release handoff

**Files:**

- Modify: `docs/validation/windows-v0.3.3-real-device-template.md`
- Modify: `docs/INSTALL.md`
- Modify: `docs/TROUBLESHOOTING.md`
- Modify: `tests/test-windows-v033-release-chain.sh`

**Acceptance:**

- Add a failing documentation-contract assertion first, then make it pass.
- Give the exact non-secret formal build command using the canonical evidence JSON, outside-repository output, a Base64 P-256 SPKI public key, and an HTTPS compatibility-pack URI.
- State clearly that private keys never enter the repository or command line, a complete Windows 11 x64 real-device evidence matrix is still required, and no v0.3.3 installer is currently published.
- Explain ordinary installation and compatibility recovery without asking users to edit selector files.
- Run the full release-chain contract, Windows solution tests, and `git diff --check`; record outputs and commit.
