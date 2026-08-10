# Codex Usage Sidebar macOS Installer and Release Assets Design

## Context

Codex Usage Sidebar is currently distributed as a Codex marketplace plugin whose session hook
installs a native AppKit companion. That path is reliable for technical users but requires several
terminal commands. The project will add a graphical macOS installer and publish it as a first-class
GitHub Release asset.

The release layout follows the conventions used by `chenhg5/cc-connect`: deterministic asset names
containing project, version, platform, and architecture; a checksum manifest; concise installation
instructions; and artifacts built from the release commit rather than uploaded from an unrelated
local build.

## Goals

- Let an Apple Silicon Mac user download one DMG and install, repair, or uninstall the project from
  a native graphical application.
- Preserve the existing marketplace plugin, isolated Codex home, LaunchAgent, and companion
  architecture rather than creating a second installation model.
- Guide the two actions macOS cannot safely automate: Codex OAuth authorization and Accessibility
  approval.
- Produce reproducible, checksum-covered GitHub Release assets from the same tested source commit.
- Keep official Codex application files read-only and preserve the current upgrade boundary.

## Non-goals

- Intel Mac, Windows, and Linux packages are not included because the native companion is currently
  Apple Silicon and AppKit-only.
- The installer will not bypass Gatekeeper, Accessibility consent, OAuth, or other operating-system
  security controls.
- The first installer release will not add a background auto-updater. Users can install a newer DMG
  or upgrade through the existing marketplace flow.

## Visual decision brief

- **Direction:** Skip new concept variants and use the existing Codex visual language plus native
  macOS controls. The user's `cc-connect` reference is the release-packaging source of truth.
- **Feeling:** Professional, trustworthy, restrained, and easy to recover when a step fails.
- **Must preserve:** One primary action, clear step status, visible installed version, repair and
  uninstall actions, and explicit OAuth and Accessibility guidance.
- **Visual constraints:** Semantic macOS window/background/separator colors, system typography,
  compact blue status accents, no decorative gradients, and automatic light/dark appearance.
- **Responsive intent:** One fixed minimum window size with a flexible content column; controls must
  remain usable under macOS text scaling and in both Chinese and English.
- **Accessibility:** Keyboard navigation, VoiceOver labels, visible focus, sufficient contrast,
  no color-only status communication, and no required animation.
- **Avoid:** Custom browser-like chrome, terminal logs as the default interface, fake permission
  completion, and visual styling that competes with Codex.

## User experience

The DMG contains `Codex Usage Sidebar Installer.app` and a short `README` link. Opening the app shows
one window with five sequential states:

1. **Check** verifies macOS 14 or later, arm64, Codex desktop, the Codex CLI, and writable user
   installation directories.
2. **Install** copies the embedded, version-matched plugin payload to a stable user directory,
   installs the marketplace plugin, runs the existing atomic companion installer, and starts the
   LaunchAgent.
3. **Authorize Codex** reports whether the isolated Codex home is authenticated and launches the
   official `codex login` flow when needed.
4. **Allow Accessibility** checks the companion's trust state, opens the correct System Settings
   pane, and waits for the user to grant access.
5. **Verify** checks the managed PID, bundle version, signature validity, app-server quota response,
   and visible runtime state before showing success.

The same window exposes secondary **Repair** and **Uninstall** actions. Repair reuses the existing
forced atomic replacement path. Uninstall removes only the exact companion support directory,
LaunchAgent, plugin installation, and this project's marketplace entry after confirmation.

## Architecture

### Installer application

A new Swift package target builds a native SwiftUI/AppKit installer. Presentation code only renders
an immutable installation state. An `InstallerCoordinator` sequences small services:

- `PrerequisiteChecker` locates Codex and validates platform requirements.
- `PayloadInstaller` copies the embedded plugin to a stable staging location and invokes the
  existing `sidebar-control.sh` contract.
- `MarketplaceInstaller` invokes supported `codex plugin` commands and captures structured results.
- `AuthorizationChecker` uses the isolated `CODEX_HOME` and launches the official login command.
- `AccessibilityChecker` reports trust without claiming that permission was granted prematurely.
- `InstallationVerifier` reads the existing sanitized runtime state and runs the live quota probe.

Commands use fixed argument arrays through `Process`; user-controlled strings are never evaluated
by a shell. Detailed logs are written locally and exposed behind a disclosure control.

### Embedded payload

The installer embeds the exact `plugins/codex-usage-sidebar` directory from the release commit. It
copies that payload to:

```text
~/Library/Application Support/CodexUsageSidebar/Plugin
```

before invoking the existing control script. This keeps `plugin-root.txt` valid after the DMG is
ejected and lets repair continue to work. The marketplace plugin remains the canonical update and
Codex-discovery path.

### Package scripts

- `scripts/build-installer.sh` builds the arm64 installer app and assembles its resource bundle.
- `scripts/package-installer.sh` creates a deterministic compressed DMG and release checksum entries.
- `scripts/test-installer.sh` exercises prerequisite, path-safety, command-construction, install,
  repair, and uninstall behavior against isolated fixtures.

## Release assets

The first installer release increments the project to `v0.3.0` because it adds a new public
installation surface. GitHub Release Assets will contain:

```text
codex-usage-sidebar-v0.3.0-macos-arm64.dmg
codex-usage-sidebar-v0.3.0-plugin.zip
SHA256SUMS.txt
PROVENANCE.json
```

`SHA256SUMS.txt` covers every downloadable binary/archive. `PROVENANCE.json` records the source
commit, workflow run, artifact identifiers, DMG digest, plugin ZIP digest, installer executable
digest, companion executable digest, architecture, SDK, and signing/notarization state.

## Signing and notarization policy

Local and pull-request builds may use ad-hoc signing so the complete installer can be tested without
publishing it. A production release supports Developer ID signing and Apple notarization through
GitHub Actions secrets. When those credentials are absent, the release can mirror `cc-connect`'s
raw-asset model, but the release notes and installer documentation must explicitly state that users
may need **Open** from Finder's context menu. It must never claim to be notarized.

When credentials become available, the workflow signs the nested companion and installer from the
inside out, enables the hardened runtime, submits the DMG with `notarytool`, staples the ticket, and
verifies it with both `codesign` and `spctl`. The artifact names and user flow remain unchanged.

## CI and publishing

The existing macOS 26 CI job will additionally:

1. run installer unit and fixture tests;
2. build the installer for arm64;
3. validate nested signatures, bundle versions, SDK, and payload identity;
4. create and mount-test the DMG;
5. verify checksums and reject metadata or generated-file leakage;
6. upload the DMG, plugin ZIP, checksums, and provenance as one immutable workflow artifact.

A tag-driven release job downloads that exact tested artifact and uploads its files to GitHub
Release Assets. It does not rebuild after the tag. Release notes show the DMG first as the normal
installation path and retain marketplace commands as the advanced/manual path.

## Failure handling

- Missing Codex or CLI produces a direct remediation action without partial installation.
- A failed copy or signature check leaves the previous working app in place.
- Marketplace failure does not silently report success; retry and log details remain available.
- OAuth and Accessibility stay in explicit waiting states until independently verified.
- Verification failure offers Repair and diagnostics, not a false success screen.
- Uninstall validates every destructive target against exact user-library paths.

## Verification

- Unit-test state transitions and command construction.
- Fixture-test installation, forced repair, rollback, and uninstall with no writes outside a
  temporary home.
- Mount the generated DMG, launch the app, and verify light/dark, Chinese/English, keyboard, and
  VoiceOver states.
- Run the complete existing Swift, lifecycle, signing, live-data, and repository-validation suites.
- Download the final GitHub assets, verify `SHA256SUMS.txt`, provenance, architecture, version,
  signatures, and release-tag commit before announcing publication.
