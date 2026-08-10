import AppKit
import Foundation
import InstallerCore

@MainActor
final class InstallerViewModel: ObservableObject {
    @Published var presentation = InstallerPresentationState.initial
    @Published var message: String
    @Published var details = ""
    @Published var isBusy = false

    let copy: InstallerCopy
    let paths: InstallerPaths

    init() {
        let language = Locale.preferredLanguages.first ?? "en"
        copy = InstallerCopy.forLanguageIdentifier(language)
        let resources = Bundle.main.resourceURL ?? Bundle.main.bundleURL
        paths = InstallerPaths(
            homeDirectory: FileManager.default.homeDirectoryForCurrentUser,
            payloadRoot: resources.appendingPathComponent("payload", isDirectory: true),
            codexExecutable: Self.locateCodexExecutable()
        )
        message = copy.readyMessage
    }

    var primaryTitle: String {
        switch presentation.phase {
        case .waiting(.authorizeCodex): copy.authorize
        case .waiting(.accessibility): copy.openAccessibility
        case .succeeded: copy.verify
        default: copy.install
        }
    }

    func primaryAction() {
        switch presentation.phase {
        case .waiting(.authorizeCodex): authorizeCodex()
        case .waiting(.accessibility): openAccessibilitySettings()
        case .succeeded: verify()
        default: install()
        }
    }

    func install() {
        guard !isBusy else { return }
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                presentation.begin(.check)
                try checkPrerequisites()
                presentation.complete(.check)

                presentation.begin(.install)
                try await Self.copyPayload(from: paths.payloadRoot, paths: paths)
                let listResult = try await Self.run(
                    InstallerCommandPlan.marketplaceList(paths: paths)
                )
                let marketplaceExists = listResult.succeeded &&
                    (try? MarketplaceInspector.containsSidebarMarketplace(
                        in: listResult.standardOutput
                    )) == true
                for command in InstallerCommandPlan.install(
                    paths: paths,
                    marketplaceAlreadyConfigured: marketplaceExists
                ) {
                    let result = try await Self.run(command)
                    appendDetails(command: command, result: result)
                    guard result.succeeded else {
                        throw InstallerViewModelError.commandFailed(result.standardError)
                    }
                }
                presentation.complete(.install)

                let loginStatus = try await Self.run(
                    InstallerCommandPlan.loginStatus(paths: paths)
                )
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
    }

    func authorizeCodex() {
        guard !isBusy else { return }
        isBusy = true
        presentation.begin(.authorizeCodex)
        Task {
            defer { isBusy = false }
            do {
                let command = InstallerCommandPlan.login(paths: paths)
                let result = try await Self.run(command)
                appendDetails(command: command, result: result)
                guard result.succeeded else {
                    throw InstallerViewModelError.commandFailed(result.standardError)
                }
                presentation.complete(.authorizeCodex)
                presentation.waitForUser(.accessibility)
                message = copy.openAccessibility
            } catch {
                fail(error)
            }
        }
    }

    func openAccessibilitySettings() {
        presentation.waitForUser(.accessibility)
        let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        )!
        NSWorkspace.shared.open(url)
        message = copy.verify
    }

    func verify() {
        guard !isBusy else { return }
        isBusy = true
        presentation.begin(.verify)
        Task {
            defer { isBusy = false }
            do {
                let command = InstallerCommandPlan.status(paths: paths)
                let result = try await Self.run(command)
                appendDetails(command: command, result: result)
                let report = InstallationVerifier.evaluate(
                    statusOutput: result.standardOutput,
                    expectedVersion: "0.2.3",
                    commandSucceeded: result.succeeded
                )
                guard report.isHealthy else {
                    throw InstallerViewModelError.verificationFailed(report.issues)
                }
                for step in InstallerStep.allCases {
                    presentation.complete(step)
                }
                message = "\(copy.successMessage) \(copy.nextTaskMessage)"
            } catch {
                fail(error)
            }
        }
    }

    func repair() {
        guard !isBusy else { return }
        isBusy = true
        presentation.begin(.install)
        Task {
            defer { isBusy = false }
            do {
                try await Self.copyPayload(from: paths.payloadRoot, paths: paths)
                let command = InstallerCommandPlan.repair(paths: paths)
                let result = try await Self.run(command)
                appendDetails(command: command, result: result)
                guard result.succeeded else {
                    throw InstallerViewModelError.commandFailed(result.standardError)
                }
                message = copy.verify
                verify()
            } catch {
                fail(error)
            }
        }
    }

    func uninstall() {
        guard !isBusy else { return }
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                for command in InstallerCommandPlan.uninstall(
                    paths: paths,
                    removeMarketplace: false
                ) where FileManager.default.isExecutableFile(atPath: command.executable.path) {
                    let result = try await Self.run(command)
                    appendDetails(command: command, result: result)
                }
                presentation = .initial
                message = copy.readyMessage
            } catch {
                fail(error)
            }
        }
    }

    private func checkPrerequisites() throws {
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

    private func appendDetails(command: CommandSpec, result: CommandResult) {
        let rendered = ([command.executable.lastPathComponent] + command.arguments).joined(separator: " ")
        details += "$ \(rendered)\n\(result.standardOutput)\(result.standardError)\n"
    }

    private func fail(_ error: Error) {
        let text = String(describing: error)
        presentation.fail(text)
        message = text
    }

    nonisolated private static func run(_ command: CommandSpec) async throws -> CommandResult {
        try await Task.detached {
            try ProcessCommandRunner().run(command)
        }.value
    }

    nonisolated private static func copyPayload(
        from payloadRoot: URL,
        paths: InstallerPaths
    ) async throws {
        try await Task.detached {
            try PayloadInstaller().install(from: payloadRoot, to: paths)
        }.value
    }

    nonisolated private static func locateCodexExecutable() -> URL {
        let candidates = [
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "/usr/bin/codex",
        ]
        return candidates
            .first { FileManager.default.isExecutableFile(atPath: $0) }
            .map { URL(fileURLWithPath: $0) }
            ?? URL(fileURLWithPath: "/opt/homebrew/bin/codex")
    }
}

private enum InstallerViewModelError: Error, CustomStringConvertible {
    case unsupportedSystem
    case codexMissing
    case payloadMissing
    case commandFailed(String)
    case verificationFailed([InstallationIssue])

    var description: String {
        switch self {
        case .unsupportedSystem: "macOS 14 or later is required."
        case .codexMissing: "The codex CLI was not found in a standard installation location."
        case .payloadMissing: "The embedded v0.2.3 payload is missing."
        case .commandFailed(let output): output.isEmpty ? "An installation command failed." : output
        case .verificationFailed(let issues): "Verification failed: \(issues)"
        }
    }
}
