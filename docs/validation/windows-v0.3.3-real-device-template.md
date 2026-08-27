# Windows v0.3.3 real-device validation record

> This record has been completed for the published v0.3.3 Windows release. The canonical sanitized
> evidence is [`windows-v0.3.3.json`](windows-v0.3.3.json); no private screenshots, account data,
> filesystem paths, task text, or raw UI Automation text are stored in this repository.

## Automated evidence (already reproducible)

The automated and real-device evidence is bound to the following immutable source:

- Source commit: `dfce4e6a93d7442e267868d8716cf882791f6155`
- Automated report: `docs/validation/windows-v0.3.3-task-6-automated.md`
- Fixture coverage: three sampled titlebar structures (`wide`, `narrow`, `right-pane`), physical DPI
  transforms at 100/125/150/200%, and English/Simplified-Chinese semantic labels.
- Automated outcome: pass
- Real-device outcome: 85/85 cases pass; completed at `2026-08-23T12:20:45Z` on Windows build
  `26200` with Codex file build `151.0.7922.170`.

Automated fixture evidence is not real-device evidence and cannot close this gate.

## Historical partial observation (superseded by the canonical record)

- Sanitized UTC timestamp: `2026-08-23T08:43:20Z`
- Tested source commit: `7582bb3`
- Codex build identity: `151.0.7922.170`
- Physical DPI scale: `200%`
- Observation: the current v0.3.3 control build exported a default-redacted diagnostic; raw UI text was disabled and the titlebar resolver returned a non-null snapshot.
- Private local evidence SHA-256: `ce844e29f38c50fead5598ac358c6b0d1afa65e71a84ef4b9af7f85db6c99472`

This observation was an early single-build UIA/titlebar-read baseline. It was superseded by the
canonical 85-case record above and is retained only for audit history.

## Canonical real-device evidence

The published evidence JSON records only sanitized case dimensions and pass results. Detailed private
screenshots, if needed for a later compatibility report, must remain outside the repository.

| Area | Required observations | Status | Sanitized evidence reference |
| --- | --- | --- | --- |
| Layout | Wide, narrow, and right-pane titlebars; restored, maximized, and fullscreen forms | Pass | [`windows-v0.3.3.json`](windows-v0.3.3.json) |
| DPI | 100%, 125%, 150%, and 200% physical DPI transforms where available | Pass | [`windows-v0.3.3.json`](windows-v0.3.3.json) |
| Language/theme | English and Simplified Chinese; light, dark, and system theme | Pass | [`windows-v0.3.3.json`](windows-v0.3.3.json) |
| Safe dock | Unknown UIA fallback, safe-rail drag/snap, lock/reset, and three-success recovery | Pass | [`windows-v0.3.3.json`](windows-v0.3.3.json) |
| Lifecycle | Codex restart/update, sleep/resume, and app-server recovery | Pass | [`windows-v0.3.3.json`](windows-v0.3.3.json) |
| Setup lifecycle | Install, repair, upgrade with retained preferences, and uninstall | Pass | [`windows-v0.3.3.json`](windows-v0.3.3.json) |
| Package | Exact x64 setup checksum, provenance, and post-install status | Pass | [`windows-v0.3.3.json`](windows-v0.3.3.json) |

## Formal release handoff (maintainers only)

The formal v0.3.3 installer is published at the [v0.3.3 GitHub Release](https://github.com/JaceHwang/codex-usage-sidebar/releases/tag/v0.3.3). The canonical evidence records the complete Windows 11 AMD64/x64 matrix for tested source commit `dfce4e6a93d7442e267868d8716cf882791f6155`; the evidence-only packaging commit is `8a97e9131c36db0f6f7cf6f815235d2edae9eac3`.

Run the formal build with the canonical evidence file and an output directory outside the repository:

```powershell
# Public inputs only — never paste a private key into this command.
pwsh scripts/build-windows-v033-setup.ps1 `
  -ValidationEvidence docs/validation/windows-v0.3.3.json `
  -OutputDirectory <outside-repository-output> `
  -CompatibilityPublicKey <base64-p256-spki> `
  -CompatibilityUpdateUri <https-compatibility-pack-uri>
```

The Base64 P-256 SPKI value is a public key and is acceptable as a build input. Private keys must never be stored in this repository or typed on the command line. No private key or other secret may be added, pasted, or typed into version-controlled files. The HTTPS URI identifies the compatibility pack; the build rejects incomplete evidence, a source commit that is not an ancestor of the packaging commit, any post-validation code change, a non-clean worktree, a non-`v0.3.3` branch, invalid key material, an insecure URI, or output inside the repository.

## Release-gate decision

- Real-device matrix complete: **Yes**
- Formal v0.3.3 setup publishable: **Yes**
- Published installer SHA-256: `5b04ef785c4e16715146986f5b293694029dc3ec8cf72a32e84bc16c1636ed08`
- Published compatibility pack SHA-256: `5610ff247e7d4d9cd1409c460855a3016a76d2a0221351b235f38ba7fe44f9e6`
