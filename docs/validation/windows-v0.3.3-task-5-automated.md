# Windows v0.3.3 Task 5 automated evidence

Date: 2026-08-23

## Scope

This record covers only Task 5 setup/package/runtime-integration documentation work. It contains no
real-device, install-lifecycle, or Task 6 claim. The v0.3.3 formal setup plan explicitly remains
non-publishable until the separate Task 6 evidence exists.

## TDD evidence

The initial focused run failed because `InstallerRuntimeHealth` and
`ICompatibilityCatalogUpdater` did not yet exist. The added tests cover localized post-install
health outcomes and priority of a P-256-verified cached schema-v2 selector catalog over the
packaged catalog, with safe packaged fallback and no background updater when configuration is
invalid. Follow-up regression coverage verifies the production scanner composition, cache IO/JSON/
null-data fallback, the controller's ten-second health bound, and v0.3.3 control-script labels.
The focused green runs reported Installer 86/86 and Windows 115/115.

## Automated verification

- `scripts/build-windows-v033-setup.ps1 -PlanOnly` emitted version `0.3.3`, x64/win-x64, schema-v2
  selectors, compatibility configuration, and `realDeviceValidated: false` / `publishableInstaller: false`.
- `dotnet test plugins/codex-usage-sidebar/windows/CodexUsageSidebar.Windows.sln --no-restore`:
  Core 54/54, Installer 86/86, Windows 115/115.
- `bash plugins/codex-usage-sidebar/tests/test-windows-hook.sh`: passed.
- `bash tests/test-windows-payload-manifest.sh`: passed positive and negative payload checks.
- `git diff --check`: passed.

## Deliberate gate

The v0.3.3 build script requires a release-supplied base64 P-256 SPKI public key and HTTPS update
URI before it will consider a formal build, then stops with the Task 6 evidence gate. No private
key is accepted or stored in the repository.
