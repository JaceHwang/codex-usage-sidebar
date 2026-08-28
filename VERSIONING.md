# Versioning and Branch Governance

> This is the versioning and branch appendix to the required
> [Project Development Governance](docs/PROJECT_GOVERNANCE.md). Follow the project guide for every
> development, GitHub delivery, and release activity.

Codex Usage Sidebar uses semantic `MAJOR.MINOR.PATCH` product versions. The public contract is the
installer and upgrade flow, persisted settings, supported-platform matrix, quota data semantics, and
documented user-visible behavior. The project is still in the `0.y.z` development phase, so an
incompatible contract change increments `MINOR` and documents migration; from `1.0.0`, it increments
`MAJOR`.

## Version decisions

| Change | Version action |
| --- | --- |
| New backward-compatible user capability or substantial information/interaction redesign | `MINOR`, for example `0.4.0` |
| Incorrect behavior, layout, localization, performance, host compatibility, or installer reliability fix | `PATCH`, for example `0.3.6` |
| Documentation, screenshots, or release-note-only changes | no product version |
| Re-signing or re-packaging without code/payload change | no product version; publish a rebuild note only |
| Compatibility-breaking installation, storage, data, or feature removal | `MINOR` while `0.y.z`; `MAJOR` from `1.0.0` |

Use `-beta.N` and `-rc.N` only for pre-release artifacts. A published version, its checksum, and its
provenance are immutable: a correction always receives a new version.

## Platform release cadence

macOS and Windows may ship independent maintenance patches. Platform-specific releases use
`macos-vX.Y.Z` and `windows-vX.Y.Z` tags and matching GitHub Release titles. A shared, parity-verified
feature ships once as `vX.Y.Z` with both platform assets. Historical tags without a platform prefix
remain unchanged.

The current platform matrix is the source-controlled
[`releases/platform-release-catalog.json`](releases/platform-release-catalog.json). It distinguishes
published releases from a planned candidate; a candidate is never presented as downloadable until its
tag, checksums, provenance, and GitHub assets exist.

## Branches

- `main` is the sole long-lived integration branch and must remain buildable and testable.
- Create short-lived `codex/feat-<topic>`, `codex/fix-<topic>`, `codex/docs-<topic>`, or
  `codex/spike-<topic>` branches from `main`; delete them after merge.
- Do not create permanent platform trunks. Keep shared contracts together and use platform-specific
  directories and CI jobs for native implementation.
- Release directly from a verified `main` commit whenever possible. For a frozen release candidate or
  production-only remediation, create a temporary `release/macos-vX.Y.Z` or
  `release/windows-vX.Y.Z` branch, accept only release fixes, tag the exact release commit, then
  delete the branch once the follow-up path is safe.
- Create `codex/hotfix-<platform>-vX.Y.Z` from the affected release tag. Merge or cherry-pick the
  tested fix back to `main` before publishing the next patch.

## Release acceptance

Every release must pass its platform tests, package validation, version-consistency checks, and
documentation review. Build the asset from the same verified commit that receives the tag; do not
replace a tested asset with a locally rebuilt one. Publish the installer, `SHA256SUMS.txt`, and
provenance together, then verify clean install, upgrade, first-open layout, runtime data refresh, and
uninstall/reinstall behavior on the target platform.
