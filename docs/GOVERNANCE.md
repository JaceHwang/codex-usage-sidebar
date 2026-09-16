# Repository governance

This repository vendors the executable policy from
[`JaceHwang/repo-governance`](https://github.com/JaceHwang/repo-governance).
The tracked `.governance/VERSION` records the template revision. The policy is
local to this repository: cloning it never depends on a central service.

## Daily development

Create a short-lived branch named `codex/<type>/<kebab-case>`, for example
`codex/fix/retry-token-read`. Allowed types and English Conventional Commit
headers are checked locally and again in pull-request CI.

Run these commands before working and before pushing:

```sh
./governance doctor
./governance check all
```

`governance doctor` repairs nothing by itself. If it reports inactive hooks,
run `./governance bootstrap`, then rerun doctor. Do not use `--no-verify`, work
directly on `main`, or manually change a product version in an ordinary commit.

## Versions and releases

Release Please manages the product version through `.release-please-manifest.json`.
A candidate value in the working tree is not evidence of a published stable release. A Release Please PR updates the product version
in `version.txt`, the plugin manifest, the macOS bundle plist, the Windows
`VersionPrefix`, and `CHANGELOG.md` together.

Stable tags are `vX.Y.Z`. `fix`, `perf`, and `revert` changes produce a patch;
`feat` produces a minor; breaking changes produce a minor while the project is
`0.x` and a major from `1.0.0` onward. Documentation, tests, build, CI, style,
and chore changes do not release by default.

Release Please creates a draft GitHub Release. This project uses staged platform
publishing: a platform must build from the exact tag/SHA, pass its verifier, and
must not overwrite an existing asset. For macOS 0.4.0, the staged publisher selects the macOS runner and delegates to the versioned
build/package/verifier scripts. It checks the exact tag, clean checkout, arm64 payload, signatures,
SDK, checksum and provenance before upload. Windows publishing remains on its existing
evidence-bound workflow until equivalent verification is implemented.

Pre-releases are only made from `codex/prerelease/alpha`,
`codex/prerelease/beta`, or `codex/prerelease/rc`; stable releases still come
from `main`.

## macOS 0.4.0 release preparation

The catalog uses `v0.4.0`, matching Release Please and the unified product version policy.
The planned catalog is release intent; only uploaded, verified assets make a platform available.
Ordinary feature commits retain the current released version; Release Please performs the bump.
After its version PR changes the bundle plist, rebuild and sign the companion from that PR's exact
source commit, update payload provenance, and rerun every required check before merging.
Never manually create a stable tag or use a dirty local build as exact release provenance.
