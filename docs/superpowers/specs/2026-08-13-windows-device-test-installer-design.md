# Windows Device-Test Installer Design

## Scope

This milestone connects the existing localized WPF installer shell to the already validated
per-user payload backend. It exists only to exercise install, repair, and uninstall on the current
Windows 11 AMD64 device. It must remain visibly and mechanically nonpublishable.

The milestone does not create a setup executable, release archive, checksum release file, GitHub
asset, or signing claim. It does not modify the official Codex package or the macOS v0.2.3 assets.

## Bundle and trust boundary

The repository device-build command produces an ignored local bundle whose name contains
`device-test`, never `setup`. The bundle contains:

- a self-contained x64 WPF manager executable outside the managed payload directory; and
- a sibling `payload` directory containing the host, control executable, official pinned Codex
  runtime, selectors, and `windows-payload.json`.

The manager accepts no arbitrary payload path in normal UI mode. It resolves only the exact sibling
`payload` directory. Assembly metadata pins the source commit and the SHA-256 of the sibling
manifest. The existing manifest validation also pins version, x64 architecture, official Codex
runtime source and digest, every payload file digest, `status=device-test`,
`realDeviceValidated=false`, and `publishableInstaller=false`.

The hidden `--device-install` helper remains for the repository build flow. Normal install and
repair share the same trusted identity but cannot promote command-line input to a trust root.

## Operations

Install and repair perform the same fail-closed replacement transaction:

1. require Windows 11 build 22000 or newer and AMD64/x64;
2. validate the sibling payload and its embedded provenance;
3. stop only a managed host whose executable path is exactly
   `%LOCALAPPDATA%\CodexUsageSidebar\Current\CodexUsageSidebar.Windows.exe`;
4. atomically stage, validate, and activate the payload using `AtomicPayloadInstaller`;
5. write the exact current-user Run value only after payload activation; and
6. start the exact managed host with its fixed background contract.

If validation or activation fails, the previous payload remains intact. Registry and process work
is expressed behind adapters so tests do not mutate the developer's machine.

Uninstall stops only the exact managed host, removes the Run value only when its data exactly
matches the expected managed command, and removes only the exact `Current` payload directory. It
does not recursively delete the installation root. The isolated `CodexHome` and `State`
directories are intentionally preserved in this beta so uninstall cannot silently destroy local
authorization or diagnostic state. The localized success copy states that local data was kept.

## UI behavior

The existing Simplified Chinese, Traditional Chinese, and English WPF window remains the UI shell.
It prominently labels the build as a local device test and not publishable. Install, repair, and
uninstall have distinct localized descriptions, progress, success, and failure copy. The window
cannot close while an operation is working, and failures return to a retryable state.

No operation requests elevation. All files and autostart state stay within the current user.

## Verification

TDD covers platform gating, trusted sibling discovery, install/repair ordering, exact-path process
selection, exact registry-value ownership, conservative uninstall, provenance failures, localized
device-test copy, and the absence of setup/release outputs. Final real-device verification builds
the ignored bundle, installs it through the visible UI, verifies one running managed host, exercises
repair and uninstall, then reinstalls so the user can continue seeing the overlay.

Publication remains blocked until the broader Windows matrix in the main v0.3.0-beta.1 design and
handoff documents is complete.
