# macOS Installer Release Assets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a native macOS arm64 installer DMG for the existing Codex Usage Sidebar v0.2.3 payload, document it in both READMEs, and add the verified DMG to the existing v0.2.3 GitHub Release Assets.

**Architecture:** Add a testable `InstallerCore` library and a thin SwiftUI `CodexUsageSidebarInstaller` executable to the existing Swift package. The app copies its embedded marketplace/plugin payload to a stable user directory, reuses `sidebar-control.sh` for atomic companion lifecycle operations, invokes `codex plugin` with fixed argument arrays, and guides OAuth and Accessibility verification. Root scripts assemble a manually signed `.app`, package a compressed DMG, generate checksums/provenance, and expose the exact tested artifact to CI and the existing release.

**Tech Stack:** Swift 6, SwiftUI/AppKit, Foundation `Process`, XCTest, Bash, `hdiutil`, `codesign`, GitHub Actions, GitHub CLI.

## Global Constraints

- Keep the plugin and companion version exactly `0.2.3`; do not change `.codex-plugin/plugin.json` or the companion `Info.plist` version.
- Name the installer asset `codex-usage-sidebar-v0.2.3-macos-arm64.dmg`.
- Retain the existing `codex-usage-sidebar-v0.2.3.zip`; never silently replace it with a source-different payload.
- Publish only macOS 14+ Apple Silicon (`arm64`).
- Keep the official Codex application read-only and install only under the current user's Library.
- Never claim Accessibility, OAuth, Developer ID signing, or notarization succeeded without direct verification.
- In the unsigned/raw-asset release path, clearly document Finder **Open** and never claim notarization.
- Update both `README.md` and `README.zh-CN.md` with the graphical installation path and retain marketplace commands as the advanced path.

---

### Task 1: Installer domain model and safe plans

**Files:**
- Modify: `plugins/codex-usage-sidebar/native/Package.swift`
- Create: `plugins/codex-usage-sidebar/native/Sources/InstallerCore/InstallerModels.swift`
- Create: `plugins/codex-usage-sidebar/native/Sources/InstallerCore/InstallerPaths.swift`
- Create: `plugins/codex-usage-sidebar/native/Sources/InstallerCore/InstallerCommandPlan.swift`
- Create: `plugins/codex-usage-sidebar/native/Tests/InstallerCoreTests/InstallerPathsTests.swift`
- Create: `plugins/codex-usage-sidebar/native/Tests/InstallerCoreTests/InstallerCommandPlanTests.swift`

**Interfaces:**
- Produces: `InstallerStep`, `InstallerPhase`, `InstallerPaths`, `CommandSpec`, and `InstallerCommandPlan`.
- `InstallerPaths.init(homeDirectory:payloadRoot:codexExecutable:)` resolves exact user-library targets.
- `InstallerCommandPlan.install(paths:marketplaceAlreadyConfigured:)` returns fixed executable/argument arrays.

- [ ] **Step 1: Add failing path and command-plan tests**

```swift
@Test func installationPathsStayInsideTheSelectedHome() {
    let paths = InstallerPaths(
        homeDirectory: URL(fileURLWithPath: "/tmp/test-home"),
        payloadRoot: URL(fileURLWithPath: "/Volumes/Installer/payload"),
        codexExecutable: URL(fileURLWithPath: "/usr/local/bin/codex")
    )
    #expect(paths.installRoot.path == "/tmp/test-home/Library/Application Support/CodexUsageSidebar")
    #expect(paths.stableMarketplaceRoot.path.hasPrefix(paths.installRoot.path + "/"))
}

@Test func installPlanUsesArgumentArraysAndVersionedSelector() {
    let commands = InstallerCommandPlan.install(paths: fixturePaths, marketplaceAlreadyConfigured: false)
    #expect(commands.contains(CommandSpec(
        executable: fixturePaths.codexExecutable,
        arguments: ["plugin", "add", "codex-usage-sidebar@codex-usage-sidebar", "--json"]
    )))
    #expect(commands.allSatisfy { !$0.arguments.joined().contains(";") })
}
```

- [ ] **Step 2: Verify RED**

Run: `swift test --package-path plugins/codex-usage-sidebar/native --filter InstallerCoreTests`

Expected: compilation fails because `InstallerCore` and the installer types do not exist.

- [ ] **Step 3: Add the library/test targets and minimal models**

```swift
public struct CommandSpec: Equatable, Sendable {
    public let executable: URL
    public let arguments: [String]
    public let environment: [String: String]
}

public enum InstallerStep: Int, CaseIterable, Sendable {
    case check, install, authorizeCodex, accessibility, verify
}

public enum InstallerPhase: Equatable, Sendable {
    case ready, running(InstallerStep), waiting(InstallerStep), succeeded, failed(String)
}
```

Implement `InstallerPaths` with `appendingPathComponent` only. Implement install, repair, status,
login-status, login, and uninstall plans as fixed `CommandSpec` arrays. No command may use
`/bin/sh -c`.

- [ ] **Step 4: Verify GREEN and run the full package suite**

Run: `swift test --package-path plugins/codex-usage-sidebar/native --filter InstallerCoreTests`

Expected: all installer core tests pass.

Run: `swift test --package-path plugins/codex-usage-sidebar/native`

Expected: all existing and new tests pass.

- [ ] **Step 5: Commit**

```bash
git add plugins/codex-usage-sidebar/native/Package.swift \
  plugins/codex-usage-sidebar/native/Sources/InstallerCore \
  plugins/codex-usage-sidebar/native/Tests/InstallerCoreTests
git commit -m "feat: add safe installer command plans"
```

### Task 2: Installer operations and verification

**Files:**
- Create: `plugins/codex-usage-sidebar/native/Sources/InstallerCore/CommandRunner.swift`
- Create: `plugins/codex-usage-sidebar/native/Sources/InstallerCore/PayloadInstaller.swift`
- Create: `plugins/codex-usage-sidebar/native/Sources/InstallerCore/InstallationVerifier.swift`
- Create: `plugins/codex-usage-sidebar/native/Tests/InstallerCoreTests/CommandRunnerTests.swift`
- Create: `plugins/codex-usage-sidebar/native/Tests/InstallerCoreTests/PayloadInstallerTests.swift`
- Create: `plugins/codex-usage-sidebar/native/Tests/InstallerCoreTests/InstallationVerifierTests.swift`

**Interfaces:**
- Consumes: `InstallerPaths` and `CommandSpec` from Task 1.
- Produces: `CommandResult`, `CommandRunning`, `PayloadInstalling`, `PayloadInstaller`, `InstallationReport`, and `InstallationVerifier`.

- [ ] **Step 1: Write failing tests for atomic copy, command results, and honest verification**

```swift
@Test func payloadInstallReplacesOnlyTheStableMarketplaceDirectory() throws {
    let fixture = try InstallerFixture.make()
    try PayloadInstaller(fileManager: .default).install(from: fixture.payload, to: fixture.paths)
    #expect(FileManager.default.fileExists(atPath: fixture.paths.pluginManifest.path))
    #expect(try String(contentsOf: fixture.paths.pluginManifest).contains("0.2.3"))
}

@Test func verificationRequiresMatchingVersionAndManagedPID() {
    let report = InstallationVerifier.evaluate(
        statusOutput: "pid=42 version=0.2.3 runtime=shown",
        expectedVersion: "0.2.3",
        commandSucceeded: true
    )
    #expect(report.isHealthy)
}
```

- [ ] **Step 2: Verify RED**

Run: `swift test --package-path plugins/codex-usage-sidebar/native --filter InstallerCoreTests`

Expected: compilation fails because the operation types do not exist.

- [ ] **Step 3: Implement minimal operations**

`CommandRunner` launches `Process` directly, captures stdout/stderr, preserves a task-specific
environment, and returns the termination status. `PayloadInstaller` validates the embedded
manifest and companion signature, copies the entire embedded marketplace to a sibling temporary
directory, and atomically replaces only `stableMarketplaceRoot`. `InstallationVerifier` requires
exit status zero, a numeric PID, `version=0.2.3`, and `runtime=shown` before success.

- [ ] **Step 4: Verify GREEN and full suite**

Run: `swift test --package-path plugins/codex-usage-sidebar/native --filter InstallerCoreTests`

Expected: all installer operation tests pass.

Run: `swift test --package-path plugins/codex-usage-sidebar/native`

Expected: complete suite passes.

- [ ] **Step 5: Commit**

```bash
git add plugins/codex-usage-sidebar/native/Sources/InstallerCore \
  plugins/codex-usage-sidebar/native/Tests/InstallerCoreTests
git commit -m "feat: add atomic installer operations"
```

### Task 3: Native graphical installer

**Files:**
- Modify: `plugins/codex-usage-sidebar/native/Package.swift`
- Create: `plugins/codex-usage-sidebar/native/Sources/CodexUsageSidebarInstaller/InstallerApp.swift`
- Create: `plugins/codex-usage-sidebar/native/Sources/CodexUsageSidebarInstaller/InstallerViewModel.swift`
- Create: `plugins/codex-usage-sidebar/native/Sources/CodexUsageSidebarInstaller/InstallerView.swift`
- Create: `plugins/codex-usage-sidebar/native/Sources/CodexUsageSidebarInstaller/InstallerLocalization.swift`
- Create: `plugins/codex-usage-sidebar/native/Tests/InstallerCoreTests/InstallerPresentationTests.swift`

**Interfaces:**
- Consumes: installer paths, operations, plans, and reports from Tasks 1-2.
- Produces: executable product `CodexUsageSidebarInstaller` and a localized single-window workflow.

- [ ] **Step 1: Write failing presentation-state tests**

```swift
@Test func accessibilityWaitDoesNotBecomeSuccessWithoutVerification() {
    var model = InstallerPresentationState.initial
    model.begin(.accessibility)
    model.waitForUser(.accessibility)
    #expect(model.phase == .waiting(.accessibility))
    #expect(model.completedSteps.contains(.accessibility) == false)
}

@Test func simplifiedChineseCopyIncludesFinderOpenInstruction() {
    #expect(InstallerCopy.simplifiedChinese.finderOpen.contains("右键"))
}
```

- [ ] **Step 2: Verify RED**

Run: `swift test --package-path plugins/codex-usage-sidebar/native --filter InstallerPresentationTests`

Expected: compilation fails because presentation state and localized copy are absent.

- [ ] **Step 3: Implement the SwiftUI app**

Create a 720x500 native window with a five-step status column and one focused content panel. Use
semantic colors and system typography. The primary button changes among Install, Authorize Codex,
Open Accessibility Settings, Verify, and Repair. Secondary actions expose logs and confirmed
uninstall. `InstallerViewModel` performs work in `Task`, updates UI on `MainActor`, and never marks
OAuth or Accessibility complete solely because a button was clicked.

- [ ] **Step 4: Verify GREEN, compile both products, and inspect accessibility metadata**

Run: `swift test --package-path plugins/codex-usage-sidebar/native --filter InstallerPresentationTests`

Expected: presentation tests pass.

Run: `swift build -c release --package-path plugins/codex-usage-sidebar/native --product CodexUsageSidebarInstaller`

Expected: arm64 installer executable builds without warnings.

- [ ] **Step 5: Commit**

```bash
git add plugins/codex-usage-sidebar/native
git commit -m "feat: add native macOS installer"
```

### Task 4: Deterministic app and DMG packaging

**Files:**
- Create: `scripts/build-installer.sh`
- Create: `scripts/package-installer.sh`
- Create: `tests/test-installer-package.sh`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: `CodexUsageSidebarInstaller` executable and current tracked plugin payload.
- Produces: `.dist/Codex Usage Sidebar Installer.app`, `.dist/codex-usage-sidebar-v0.2.3-macos-arm64.dmg`, installer checksums, and installer provenance.

- [ ] **Step 1: Write a failing shell packaging test**

The test must reject a wrong version, missing embedded manifest, non-arm64 executable, invalid
signature, a DMG without the installer app, and any artifact name other than exactly
`codex-usage-sidebar-v0.2.3-macos-arm64.dmg`.

- [ ] **Step 2: Verify RED**

Run: `bash tests/test-installer-package.sh`

Expected: failure because installer packaging scripts and assets do not exist.

- [ ] **Step 3: Implement build and package scripts**

`build-installer.sh` reads base version from `plugin.json`, requires `0.2.3`, builds the Swift
product, assembles the app bundle, copies `.agents/plugins/marketplace.json` and the exact plugin
tree under `Contents/Resources/payload`, writes an `Info.plist` with version `0.2.3`, and signs the
nested bundle with `CUS_INSTALLER_SIGN_IDENTITY` or ad-hoc `-`.

`package-installer.sh` creates a staging directory with the installer app and an English/Chinese
first-open note, creates a compressed DMG with `hdiutil`, mount-verifies it, and writes checksums and
JSON provenance. No script may package `.git`, `.build`, `.dist`, `.DS_Store`, or worktree metadata.

- [ ] **Step 4: Verify GREEN and inspect the DMG**

Run: `bash tests/test-installer-package.sh`

Expected: package regression tests pass.

Run: `bash scripts/build-installer.sh && bash scripts/package-installer.sh`

Expected: exact v0.2.3 DMG exists, mounts, contains the app, and passes `codesign --verify --deep --strict`.

- [ ] **Step 5: Commit**

```bash
git add .gitignore scripts/build-installer.sh scripts/package-installer.sh tests/test-installer-package.sh
git commit -m "build: package the v0.2.3 macOS installer"
```

### Task 5: CI, release metadata, and bilingual installation docs

**Files:**
- Modify: `.github/workflows/ci.yml`
- Create: `.github/workflows/publish-installer.yml`
- Modify: `README.md`
- Modify: `README.zh-CN.md`
- Modify: `docs/INSTALL.md`
- Modify: `docs/releases/v0.2.3.md`
- Modify: `scripts/validate-public-repo.sh`

**Interfaces:**
- Consumes: package scripts and exact artifact names from Task 4.
- Produces: CI-tested installer artifact, manually dispatched existing-release upload, and complete user documentation.

- [ ] **Step 1: Extend validation first and verify it rejects missing documentation/assets**

Require both READMEs to link the exact v0.2.3 DMG release URL, require the unsigned Finder Open
warning in both languages, lint both workflows, and check that installer package scripts are
executable. Run `bash scripts/validate-public-repo.sh` and confirm it fails before documentation and
workflow changes are added.

- [ ] **Step 2: Add CI and release workflows**

CI runs installer tests, builds and packages the DMG, verifies its checksum, and uploads the DMG
plus installer provenance as `codex-usage-sidebar-installer-v0.2.3`. `publish-installer.yml` uses
`workflow_dispatch`, `contents: write`, checks that the target release is `v0.2.3`, downloads the
exact CI artifact without rebuilding, merges the DMG digest into `SHA256SUMS.txt`, and uploads the
DMG/checksum/installer provenance to the existing release with `gh release upload --clobber`.

- [ ] **Step 3: Update English and Chinese user instructions**

Place **Download the installer / 下载图形安装器** first under Quick install. Document: download the
DMG from Assets, open it, right-click Open if Gatekeeper blocks the raw asset, click Install, finish
Codex login, enable Accessibility, and click Verify. Keep marketplace commands under an Advanced
manual installation subsection. Add repair, update, and uninstall behavior to `docs/INSTALL.md` and
record that the installer is a new asset for the existing v0.2.3 payload in release notes.

- [ ] **Step 4: Verify docs, workflows, links, and full repository**

Run: `git diff --check`

Run: `bash scripts/validate-public-repo.sh`

Run: `bash tests/test-installer-package.sh`

Run: `swift test --package-path plugins/codex-usage-sidebar/native`

Expected: every command exits zero.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows README.md README.zh-CN.md docs/INSTALL.md \
  docs/releases/v0.2.3.md scripts/validate-public-repo.sh
git commit -m "docs: add v0.2.3 graphical installation"
```

### Task 6: Visual QA, review, promotion, and existing-release upload

**Files:**
- Modify only if verification finds a concrete defect in the files from Tasks 1-5.

**Interfaces:**
- Consumes: all local commits and CI artifacts.
- Produces: merged main branch and verified v0.2.3 GitHub Release Assets.

- [ ] **Step 1: Perform local installer QA**

Mount the DMG and launch the installer. Verify English/Chinese, light/dark, keyboard focus, disabled,
running, waiting, failure, success, repair, and uninstall confirmation states. Use an isolated test
home for destructive lifecycle checks; do not overwrite the user's formal companion during fixture
tests.

- [ ] **Step 2: Run complete verification and request code review**

Run every Task 5 verification plus `file`/`lipo`, `codesign`, `hdiutil verify`, mounted payload
version checks, and plugin validation. Request an independent review against this plan and fix all
Critical or Important findings with regression tests.

- [ ] **Step 3: Push the feature branch and wait for CI**

Push `codex/macos-installer-assets`, open a ready PR to `main`, and require all checks to pass.

- [ ] **Step 4: Merge and dispatch the installer release workflow**

Merge the reviewed branch, wait for main CI, dispatch `publish-installer.yml` against the successful
main CI run and target release `v0.2.3`, then wait for the upload workflow to pass.

- [ ] **Step 5: Verify downloaded GitHub Assets end to end**

Download the DMG, ZIP, checksums, and both provenance files into a fresh temporary directory. Verify
checksums, DMG mount, app version `0.2.3`, arm64 executable, signature state, embedded plugin version,
companion executable hash, installer source commit, workflow run, and target release tag. Confirm
the Release Assets list exposes the DMG with the exact required name before reporting completion.
