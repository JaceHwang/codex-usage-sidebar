import AppKit
import Foundation
import InstallerCore

struct InstallerViewModelDependencies: Sendable {
    var runCommand: @Sendable (CommandSpec) async throws -> CommandResult
    var installPayload: @Sendable (URL, InstallerPaths) async throws -> Void
    var checkPrerequisites: @Sendable (InstallerPaths) throws -> Void
    var canRunCommand: @Sendable (CommandSpec) -> Bool
    var openAccessibilitySettings: @MainActor @Sendable (URL) -> Void
}

@MainActor
final class InstallerViewModel: ObservableObject {
    @Published var presentation = InstallerPresentationState.initial
    @Published var message: String
    @Published var details = ""
    @Published var isBusy = false

    let copy: InstallerCopy
    let paths: InstallerPaths
    private let dependencies: InstallerViewModelDependencies

    convenience init() {
        let language = Locale.preferredLanguages.first ?? "en"
        let resources = Bundle.main.resourceURL ?? Bundle.main.bundleURL
        let paths = InstallerPaths(
            homeDirectory: FileManager.default.homeDirectoryForCurrentUser,
            payloadRoot: resources.appendingPathComponent("payload", isDirectory: true),
            codexExecutable: CodexExecutableLocator.locate()
                ?? URL(fileURLWithPath: "/opt/homebrew/bin/codex")
        )
        self.init(
            copy: InstallerCopy.forLanguageIdentifier(language),
            paths: paths,
            dependencies: Self.liveDependencies
        )
    }

    init(
        copy: InstallerCopy,
        paths: InstallerPaths,
        dependencies: InstallerViewModelDependencies
    ) {
        self.copy = copy
        self.paths = paths
        self.dependencies = dependencies
        message = copy.readyMessage
    }

    var primaryTitle: String {
        switch presentation.phase {
        case .waiting(.authorizeCodex): copy.authorize
        case .waiting(.accessibility): copy.openAccessibility
        case .waiting(.verify), .succeeded: copy.verify
        default: copy.install
        }
    }

    func primaryAction() async {
        switch presentation.phase {
        case .waiting(.authorizeCodex): await authorizeCodex()
        case .waiting(.accessibility): openAccessibilitySettings()
        case .waiting(.verify), .succeeded: await verify()
        default: await install()
        }
    }

    func install() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            presentation.begin(.check)
            try dependencies.checkPrerequisites(paths)
            presentation.complete(.check)

            presentation.begin(.install)
            try await dependencies.installPayload(paths.payloadRoot, paths)
            let marketplaceAlreadyConfigured = try await inspectMarketplaceOwnership()

            for command in InstallerCommandPlan.install(
                paths: paths,
                marketplaceAlreadyConfigured: marketplaceAlreadyConfigured
            ) {
                let result = try await runRequired(command)
                guard result.succeeded else {
                    throw InstallerViewModelError.commandFailed(
                        command: command,
                        output: result.standardError
                    )
                }
            }
            presentation.complete(.install)

            let loginCommand = InstallerCommandPlan.loginStatus(paths: paths)
            let loginStatus = try await runRequired(loginCommand)
            if loginStatus.succeeded {
                presentation.complete(.authorizeCodex)
                presentation.waitForUser(.accessibility)
                message = copy.openAccessibility
            } else {
                presentation.waitForUser(.authorizeCodex)
                message = copy.authorize
            }
        } catch {
            fail(error)
        }
    }

    func authorizeCodex() async {
        guard !isBusy else { return }
        isBusy = true
        presentation.begin(.authorizeCodex)
        defer { isBusy = false }
        do {
            let login = InstallerCommandPlan.login(paths: paths)
            let loginResult = try await runRequired(login)
            guard loginResult.succeeded else {
                throw InstallerViewModelError.commandFailed(
                    command: login,
                    output: loginResult.standardError
                )
            }

            let status = InstallerCommandPlan.loginStatus(paths: paths)
            let statusResult = try await runRequired(status)
            guard statusResult.succeeded else {
                throw InstallerViewModelError.codexLoginNotVerified
            }
            presentation.complete(.authorizeCodex)
            presentation.waitForUser(.accessibility)
            message = copy.openAccessibility
        } catch {
            fail(error)
        }
    }

    func openAccessibilitySettings() {
        presentation.accessibilitySettingsOpened()
        let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        )!
        dependencies.openAccessibilitySettings(url)
        message = copy.verify
    }

    func verify() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await performVerification()
        } catch {
            fail(error)
        }
    }

    func repair() async {
        guard !isBusy else { return }
        isBusy = true
        presentation.begin(.install)
        defer { isBusy = false }
        do {
            try await dependencies.installPayload(paths.payloadRoot, paths)
            let marketplaceAlreadyConfigured = try await inspectMarketplaceOwnership()
            for command in InstallerCommandPlan.repairInstallation(
                paths: paths,
                marketplaceAlreadyConfigured: marketplaceAlreadyConfigured
            ) {
                let result = try await runRequired(command)
                guard result.succeeded else {
                    throw InstallerViewModelError.commandFailed(
                        command: command,
                        output: result.standardError
                    )
                }
            }
            try await performVerification()
        } catch {
            fail(error)
        }
    }

    func uninstall() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }

        var failures: [String] = []
        var removePlugin = false
        var removeMarketplace = false
        let listCommand = InstallerCommandPlan.marketplaceList(paths: paths)
        if !dependencies.canRunCommand(listCommand) {
            failures.append(missingExecutableDescription(for: listCommand))
        } else {
            do {
                let listResult = try await dependencies.runCommand(listCommand)
                appendDetails(command: listCommand, result: listResult)
                if listResult.succeeded {
                    let configuration = try MarketplaceInspector.configuration(
                        in: listResult.standardOutput,
                        expectedRoot: paths.stableMarketplaceRoot
                    )
                    switch configuration {
                    case .absent:
                        removePlugin = true
                    case .installerOwned:
                        removePlugin = true
                        removeMarketplace = true
                    case .conflict(let root):
                        failures.append(
                            String(describing: InstallerViewModelError.marketplaceConflict(root))
                        )
                    }
                } else {
                    failures.append(failureDescription(for: listCommand, result: listResult))
                }
            } catch {
                failures.append(thrownDescription(for: listCommand, error: error))
            }
        }

        for command in InstallerCommandPlan.uninstall(
            paths: paths,
            removePlugin: removePlugin,
            removeMarketplace: removeMarketplace
        ) {
            guard dependencies.canRunCommand(command) else {
                failures.append(missingExecutableDescription(for: command))
                continue
            }
            do {
                let result = try await dependencies.runCommand(command)
                appendDetails(command: command, result: result)
                if !result.succeeded {
                    failures.append(failureDescription(for: command, result: result))
                }
            } catch {
                failures.append(thrownDescription(for: command, error: error))
            }
        }

        if failures.isEmpty {
            presentation = .initial
            message = copy.readyMessage
        } else {
            fail(InstallerViewModelError.uninstallIncomplete(failures))
        }
    }

    private func inspectMarketplaceOwnership() async throws -> Bool {
        let command = InstallerCommandPlan.marketplaceList(paths: paths)
        let result = try await runRequired(command)
        guard result.succeeded else {
            throw InstallerViewModelError.commandFailed(
                command: command,
                output: result.standardError
            )
        }
        switch try MarketplaceInspector.configuration(
            in: result.standardOutput,
            expectedRoot: paths.stableMarketplaceRoot
        ) {
        case .absent:
            return false
        case .installerOwned:
            return true
        case .conflict(let root):
            throw InstallerViewModelError.marketplaceConflict(root)
        }
    }

    private func performVerification() async throws {
        presentation.begin(.verify)
        let statusCommand = InstallerCommandPlan.status(paths: paths)
        let loginCommand = InstallerCommandPlan.loginStatus(paths: paths)
        let accessibilityCommand = InstallerCommandPlan.accessibilityStatus(paths: paths)
        let status = try await runRequired(statusCommand)
        let login = try await runRequired(loginCommand)
        let accessibility = try await runRequired(accessibilityCommand)
        let report = InstallationVerifier.evaluate(
            statusOutput: status.standardOutput,
            expectedVersion: "0.3.3",
            statusCommandSucceeded: status.succeeded,
            loginCommandSucceeded: login.succeeded,
            accessibilityOutput: accessibility.standardOutput,
            accessibilityCommandSucceeded: accessibility.succeeded
        )
        guard report.isHealthy else {
            throw InstallerViewModelError.verificationFailed(report.issues)
        }
        for step in InstallerStep.allCases {
            presentation.complete(step)
        }
        message = "\(copy.successMessage) \(copy.nextTaskMessage)"
    }

    private func runRequired(_ command: CommandSpec) async throws -> CommandResult {
        guard dependencies.canRunCommand(command) else {
            throw InstallerViewModelError.requiredExecutableMissing(command)
        }
        let result = try await dependencies.runCommand(command)
        appendDetails(command: command, result: result)
        return result
    }

    private func appendDetails(command: CommandSpec, result: CommandResult) {
        details += "$ \(Self.render(command))\n\(result.standardOutput)\(result.standardError)\n"
    }

    private func missingExecutableDescription(for command: CommandSpec) -> String {
        "\(Self.render(command)): required executable is missing"
    }

    private func failureDescription(for command: CommandSpec, result: CommandResult) -> String {
        let detail = result.standardError.isEmpty
            ? "exit status \(result.terminationStatus)"
            : result.standardError
        return "\(Self.render(command)): \(detail)"
    }

    private func thrownDescription(for command: CommandSpec, error: Error) -> String {
        "\(Self.render(command)): \(error)"
    }

    private func fail(_ error: Error) {
        let text = String(describing: error)
        presentation.fail(text)
        message = text
    }

    nonisolated private static func render(_ command: CommandSpec) -> String {
        ([command.executable.lastPathComponent] + command.arguments).joined(separator: " ")
    }

    nonisolated private static func checkPrerequisites(paths: InstallerPaths) throws {
        guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 14 else {
            throw InstallerViewModelError.unsupportedSystem
        }
        guard FileManager.default.isExecutableFile(atPath: paths.codexExecutable.path) else {
            throw InstallerViewModelError.codexMissing
        }
        let manifest = paths.payloadRoot
            .appendingPathComponent("plugins/codex-usage-sidebar/.codex-plugin/plugin.json")
        guard FileManager.default.fileExists(atPath: manifest.path) else {
            throw InstallerViewModelError.payloadMissing
        }
    }

    nonisolated private static func run(_ command: CommandSpec) async throws -> CommandResult {
        let task = Task.detached {
            try ProcessCommandRunner().run(command)
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    nonisolated private static func copyPayload(
        from payloadRoot: URL,
        paths: InstallerPaths
    ) async throws {
        let task = Task.detached {
            try PayloadInstaller().install(from: payloadRoot, to: paths)
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private static var liveDependencies: InstallerViewModelDependencies {
        InstallerViewModelDependencies(
            runCommand: { try await run($0) },
            installPayload: { try await copyPayload(from: $0, paths: $1) },
            checkPrerequisites: { try checkPrerequisites(paths: $0) },
            canRunCommand: {
                FileManager.default.isExecutableFile(atPath: $0.executable.path)
            },
            openAccessibilitySettings: { NSWorkspace.shared.open($0) }
        )
    }
}

private enum InstallerViewModelError: Error, CustomStringConvertible {
    case unsupportedSystem
    case codexMissing
    case payloadMissing
    case codexLoginNotVerified
    case marketplaceConflict(String?)
    case requiredExecutableMissing(CommandSpec)
    case commandFailed(command: CommandSpec, output: String)
    case verificationFailed([InstallationIssue])
    case uninstallIncomplete([String])

    var description: String {
        switch self {
        case .unsupportedSystem:
            "macOS 14 or later is required."
        case .codexMissing:
            "The codex CLI was not found in a standard installation location."
        case .payloadMissing:
            "The embedded v0.3.3 payload is missing."
        case .codexLoginNotVerified:
            "Codex login completed but the isolated login status is not authenticated."
        case .marketplaceConflict(let root):
            "Codex marketplace conflict: the name codex-usage-sidebar belongs to \(root ?? "an unknown external root")."
        case .requiredExecutableMissing(let command):
            "Required executable is missing: \(command.executable.path)"
        case .commandFailed(let command, let output):
            output.isEmpty
                ? "Installer command failed: \(command.executable.lastPathComponent) \(command.arguments.joined(separator: " "))"
                : output
        case .verificationFailed(let issues):
            "Verification failed: \(issues)"
        case .uninstallIncomplete(let failures):
            "Uninstall incomplete; some installed state may remain:\n- \(failures.joined(separator: "\n- "))"
        }
    }
}
