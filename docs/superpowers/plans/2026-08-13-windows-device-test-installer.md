# Windows Device-Test Installer Implementation Plan

## Goal

Provide a provenance-bound, localized WPF device-test manager for install, repair, and conservative
uninstall on Windows 11 AMD64 without emitting a publishable setup or touching macOS v0.2.3 assets.

## Tasks

1. Add red tests for trusted sibling-payload discovery, Windows 11/x64 gating, and the explicit
   nonpublishable UI copy.
2. Add red tests for exact managed-process stopping, exact HKCU Run ownership, operation ordering,
   rollback-safe install/repair, and uninstall that preserves `CodexHome` and `State`.
3. Implement small filesystem, process, registry, and host-launch adapters plus the device-test UI
   action orchestrator.
4. Wire the WPF entry point to assembly-pinned sibling-payload actions while preserving the hidden
   provenance-bound device install helper.
5. Add a repository PowerShell build command that creates only an ignored
   `windows-x64-device-test` bundle and embeds commit/manifest trust metadata.
6. Extend repository gates to reject `setup`/release-shaped outputs from the device-test command.
7. Run focused tests, the full Windows solution suite/build/format checks, manifest and workflow
   gates, macOS freeze protection, and `git diff --check`.
8. Build the local bundle, use its visible WPF UI to exercise install, repair, and uninstall, then
   reinstall and verify exactly one running managed host and a visible overlay in the current Codex
   UI.

## Safety checkpoints

- Do not accept a UI-supplied payload path or source commit.
- Do not remove the installation root, `CodexHome`, or `State`.
- Do not alter a Run value owned by another command.
- Do not stop a same-named process from another executable path.
- Do not create or upload setup/release artifacts.
- Do not weaken fail-hidden UIA placement behavior.
