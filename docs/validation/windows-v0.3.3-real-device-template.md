# Windows v0.3.3 real-device validation record

> Template only. Do not mark a row passed, add a date, or set the release gate to publishable
> until the named observation has occurred on a Windows 11 AMD64/x64 device with a signed-in Codex
> session. Keep all evidence sanitized: no account addresses, filesystem paths, task text, or raw
> UI Automation text.

## Automated evidence (already reproducible)

Record the source commit and the current automated report here after rerunning it:

- Source commit: `<commit>`
- Automated report: `docs/validation/windows-v0.3.3-task-6-automated.md`
- Fixture coverage: three sampled titlebar structures (`wide`, `narrow`, `right-pane`), physical DPI
  transforms at 100/125/150/200%, and English/Simplified-Chinese semantic labels.
- Automated outcome: `<pass/fail with command output summary>`

Automated fixture evidence is not real-device evidence and cannot close this gate.

## Partial real-device observation (does not complete a matrix row)

- Sanitized UTC timestamp: `2026-08-23T08:43:20Z`
- Tested source commit: `7582bb3`
- Codex build identity: `151.0.7922.170`
- Physical DPI scale: `200%`
- Observation: the current v0.3.3 control build exported a default-redacted diagnostic; raw UI text was disabled and the titlebar resolver returned a non-null snapshot.
- Private local evidence SHA-256: `ce844e29f38c50fead5598ac358c6b0d1afa65e71a84ef4b9af7f85db6c99472`

This observation proves only a single current-build UIA/titlebar-read baseline. It does **not** prove
the wide/narrow/right-pane, language/theme, safe-dock interaction, lifecycle, or setup matrix rows.

## Required real-device evidence

For each completed row, record only a sanitized timestamp, build identifier, DPI, language/theme,
result, and the SHA-256 of an approved private evidence bundle. Keep screenshots cropped to the
disposable task titlebar and do not commit the bundle to this repository.

| Area | Required observations | Status | Sanitized evidence reference |
| --- | --- | --- | --- |
| Layout | Wide, narrow, and right-pane titlebars; restored, maximized, and fullscreen forms | Pending | `<private bundle SHA-256>` |
| DPI | 100%, 125%, 150%, and 200% physical DPI transforms where available | Pending | `<private bundle SHA-256>` |
| Language/theme | English and Simplified Chinese; light, dark, and system theme | Pending | `<private bundle SHA-256>` |
| Safe dock | Unknown UIA fallback, safe-rail drag/snap, lock/reset, and three-success recovery | Pending | `<private bundle SHA-256>` |
| Lifecycle | Codex restart/update, sleep/resume, and app-server recovery | Pending | `<private bundle SHA-256>` |
| Setup lifecycle | Install, repair, upgrade with retained preferences, and uninstall | Pending | `<private bundle SHA-256>` |
| Package | Exact x64 setup checksum, provenance, and post-install status | Pending | `<private bundle SHA-256>` |

## Formal release handoff (maintainers only)

No v0.3.3 installer is currently published. Do not describe the partial observation or the automated evidence above as formal device validation. A formal build is allowed only from the exact `v0.3.3` branch with a completely clean worktree, after the canonical `docs/validation/windows-v0.3.3.json` records a complete Windows 11 AMD64/x64 real-device matrix for the same source commit that will be packaged.

Run the formal build with the canonical evidence file and an output directory outside the repository:

```powershell
pwsh scripts/build-windows-v033-setup.ps1 `
  -ValidationEvidence docs/validation/windows-v0.3.3.json `
  -OutputDirectory <outside-repository-output> `
  -CompatibilityPublicKey <base64-p256-spki> `
  -CompatibilityUpdateUri <https-compatibility-pack-uri>
```

The Base64 P-256 SPKI value is a public key and is acceptable as a build input. Private keys must never be stored in this repository or typed on the command line. No private key or other secret may be added, pasted, or typed into version-controlled files. The HTTPS URI identifies the compatibility pack; the build rejects incomplete evidence, a mismatched source commit, a non-clean worktree, a non-`v0.3.3` branch, invalid key material, an insecure URI, or output inside the repository.

## Release-gate decision

- Real-device matrix complete: **No**
- Formal v0.3.3 setup publishable: **No**
- Remaining action: complete every row above, bind the sanitized private evidence to the tested
  source commit, rerun the release-package verification, and have a maintainer record the outcome.
