import Foundation
import InstallerCore
import XCTest
@testable import CodexUsageSidebarInstaller

final class InstallerViewModelTests: XCTestCase {
    @MainActor
    func testInstallAccessibilityAndVerifyReachSuccessWithDirectEvidence() async {
        let harness = CommandHarness(results: [
            .success(output: #"{"marketplaces":[]}"#),
            .success(),
            .success(),
            .success(),
            .success(output: "Logged in"),
            .success(output: "pid=42 version=0.3.1 runtime=hidden:not-foreground"),
            .success(output: "Logged in"),
            .success(output: "host=found app_server=found accessibility=granted"),
        ])
        let model = makeModel(harness: harness)

        await model.install()
        XCTAssertEqual(model.presentation.phase, .waiting(.accessibility))
        XCTAssertTrue(model.presentation.completedSteps.contains(.authorizeCodex))
        XCTAssertFalse(model.presentation.completedSteps.contains(.accessibility))

        await model.primaryAction()
        XCTAssertEqual(model.presentation.phase, .waiting(.verify))
        XCTAssertEqual(model.primaryTitle, model.copy.verify)

        await model.primaryAction()
        XCTAssertEqual(model.presentation.phase, .succeeded)
        XCTAssertEqual(model.presentation.completedSteps, Set(InstallerStep.allCases))
    }

    @MainActor
    func testRepairRevalidatesOwnedMarketplaceAndVerifiesInsideTheSameOperation() async {
        let harness = repairHarness(marketplaceJSON: installerOwnedMarketplaceJSON)
        let model = makeModel(harness: harness)

        await model.repair()

        XCTAssertFalse(model.isBusy)
        XCTAssertEqual(model.presentation.phase, .succeeded)
        XCTAssertEqual(
            harness.commands.map(\.arguments),
            [
                ["plugin", "marketplace", "list", "--json"],
                ["plugin", "add", InstallerCommandPlan.pluginSelector, "--json"],
                ["repair", "--plugin-root", paths.pluginRoot.path, "--plugin-data", paths.pluginData.path],
                ["status"],
                ["login", "status"],
                ["--diagnostic-once"],
            ]
        )
    }

    @MainActor
    func testRepairRegistersTheExactEmbeddedMarketplaceOnACleanHome() async {
        let harness = repairHarness(marketplaceJSON: #"{"marketplaces":[]}"#)
        let model = makeModel(harness: harness)

        await model.repair()

        XCTAssertEqual(model.presentation.phase, .succeeded)
        XCTAssertEqual(
            harness.commands.map(\.arguments),
            [
                ["plugin", "marketplace", "list", "--json"],
                ["plugin", "marketplace", "add", paths.stableMarketplaceRoot.path, "--json"],
                ["plugin", "add", InstallerCommandPlan.pluginSelector, "--json"],
                ["repair", "--plugin-root", paths.pluginRoot.path, "--plugin-data", paths.pluginData.path],
                ["status"],
                ["login", "status"],
                ["--diagnostic-once"],
            ]
        )
    }

    @MainActor
    func testRepairRejectsAConflictingExternalMarketplaceBeforeRegistrationOrLifecycle() async {
        let harness = repairHarness(
            marketplaceJSON: #"{"marketplaces":[{"name":"codex-usage-sidebar","root":"/tmp/external"}]}"#
        )
        let model = makeModel(harness: harness)

        await model.repair()

        guard case .failed(let message) = model.presentation.phase else {
            return XCTFail("repair must not certify an externally owned marketplace")
        }
        XCTAssertTrue(message.contains("marketplace conflict"))
        XCTAssertEqual(harness.commands.map(\.arguments), [["plugin", "marketplace", "list", "--json"]])
    }

    @MainActor
    func testVerifyDoesNotCompleteOAuthOrAccessibilityWithoutEvidence() async {
        let harness = CommandHarness(results: [
            .success(output: "pid=42 version=0.3.1 runtime=shown"),
            .failure(error: "Not logged in"),
            .success(output: "host=found app_server=found accessibility=required"),
        ])
        let model = makeModel(harness: harness)
        model.presentation.waitForUser(.verify)

        await model.verify()

        guard case .failed = model.presentation.phase else {
            return XCTFail("verification must fail without OAuth and Accessibility evidence")
        }
        XCTAssertFalse(model.presentation.completedSteps.contains(.authorizeCodex))
        XCTAssertFalse(model.presentation.completedSteps.contains(.accessibility))
    }

    @MainActor
    func testAuthorizeRechecksTheIsolatedLoginStatusBeforeAdvancing() async {
        let harness = CommandHarness(results: [
            .success(output: "Browser login completed"),
            .failure(error: "Not logged in"),
        ])
        let model = makeModel(harness: harness)
        model.presentation.waitForUser(.authorizeCodex)

        await model.authorizeCodex()

        guard case .failed = model.presentation.phase else {
            return XCTFail("authorization must not complete when login status still fails")
        }
        XCTAssertEqual(harness.commands.map(\.arguments), [["login"], ["login", "status"]])
        XCTAssertFalse(model.presentation.completedSteps.contains(.authorizeCodex))
    }

    @MainActor
    func testConflictingExternalMarketplaceStopsBeforeRegistrationOrLifecycle() async {
        let harness = CommandHarness(results: [
            .success(output: #"{"marketplaces":[{"name":"codex-usage-sidebar","root":"/tmp/external"}]}"#),
        ])
        let model = makeModel(harness: harness)

        await model.install()

        guard case .failed(let message) = model.presentation.phase else {
            return XCTFail("external marketplace conflict must fail installation")
        }
        XCTAssertTrue(message.contains("marketplace conflict"))
        XCTAssertEqual(harness.commands.map(\.arguments), [["plugin", "marketplace", "list", "--json"]])
    }

    @MainActor
    func testCorruptPayloadStopsBeforeEveryCLIAndLifecycleCommand() async {
        let harness = CommandHarness(results: [])
        var dependencies = dependencies(for: harness)
        dependencies.installPayload = { _, _ in throw FixtureError.corruptPayload }
        let model = InstallerViewModel(copy: .english, paths: paths, dependencies: dependencies)

        await model.install()

        guard case .failed = model.presentation.phase else {
            return XCTFail("corrupt payload must fail installation")
        }
        XCTAssertEqual(harness.commands, [])
    }

    @MainActor
    func testUninstallReportsEveryMissingRequiredCommandAsPartialCleanup() async {
        for missingArguments in uninstallCommandArguments {
            let harness = uninstallHarness(marketplaceJSON: installerOwnedMarketplaceJSON)
            var dependencies = dependencies(for: harness)
            dependencies.canRunCommand = { $0.arguments != missingArguments }
            let model = InstallerViewModel(copy: .english, paths: paths, dependencies: dependencies)

            await model.uninstall()

            assertPartialUninstall(model, mentioning: missingArguments)
        }
    }

    @MainActor
    func testUninstallReportsEveryNonzeroCommandAsPartialCleanup() async {
        for failingArguments in uninstallCommandArguments {
            let marketplaceJSON = installerOwnedMarketplaceJSON
            let harness = CommandHarness(handler: { command in
                if command.arguments == ["plugin", "marketplace", "list", "--json"] {
                    if command.arguments == failingArguments {
                        return .failure(error: "fixture failure")
                    }
                    return .success(output: marketplaceJSON)
                }
                return command.arguments == failingArguments
                    ? .failure(error: "fixture failure")
                    : .success()
            })
            let model = makeModel(harness: harness)

            await model.uninstall()

            assertPartialUninstall(model, mentioning: failingArguments)
        }
    }

    @MainActor
    func testUninstallResetsOnlyAfterEveryRequiredCleanupSucceeds() async {
        let harness = uninstallHarness(marketplaceJSON: installerOwnedMarketplaceJSON)
        let model = makeModel(harness: harness)
        model.presentation.complete(.check)

        await model.uninstall()

        XCTAssertEqual(model.presentation, .initial)
        XCTAssertEqual(model.message, model.copy.readyMessage)
    }

    @MainActor
    func testUninstallPreservesAConflictingExternalMarketplaceAndReportsPartialCleanup() async {
        let external = #"{"marketplaces":[{"name":"codex-usage-sidebar","root":"/tmp/external"}]}"#
        let harness = uninstallHarness(marketplaceJSON: external)
        let model = makeModel(harness: harness)

        await model.uninstall()

        guard case .failed(let message) = model.presentation.phase else {
            return XCTFail("unsafe external registration cleanup must remain visible")
        }
        XCTAssertTrue(message.contains("marketplace conflict"))
        XCTAssertEqual(
            harness.commands.map(\.arguments),
            [
                ["plugin", "marketplace", "list", "--json"],
                ["uninstall"],
            ]
        )
    }

    @MainActor
    private func assertPartialUninstall(
        _ model: InstallerViewModel,
        mentioning arguments: [String],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .failed(let message) = model.presentation.phase else {
            return XCTFail(
                "partial uninstall must remain failed for \(arguments)",
                file: file,
                line: line
            )
        }
        XCTAssertTrue(message.contains("Uninstall incomplete"), file: file, line: line)
        XCTAssertTrue(
            message.contains(arguments.joined(separator: " ")),
            "missing command details for \(arguments)",
            file: file,
            line: line
        )
    }

    @MainActor
    private func makeModel(harness: CommandHarness) -> InstallerViewModel {
        InstallerViewModel(
            copy: .english,
            paths: paths,
            dependencies: dependencies(for: harness)
        )
    }

    private func dependencies(for harness: CommandHarness) -> InstallerViewModelDependencies {
        InstallerViewModelDependencies(
            runCommand: { command in try harness.run(command) },
            installPayload: { _, _ in },
            checkPrerequisites: { _ in },
            canRunCommand: { _ in true },
            openAccessibilitySettings: { _ in }
        )
    }

    private func uninstallHarness(marketplaceJSON: String) -> CommandHarness {
        CommandHarness(handler: { command in
            if command.arguments == ["plugin", "marketplace", "list", "--json"] {
                return .success(output: marketplaceJSON)
            }
            return .success()
        })
    }

    private func repairHarness(marketplaceJSON: String) -> CommandHarness {
        CommandHarness(handler: { command in
            switch command.arguments {
            case ["plugin", "marketplace", "list", "--json"]:
                return .success(output: marketplaceJSON)
            case ["status"]:
                return .success(output: "pid=42 version=0.3.1 runtime=shown")
            case ["login", "status"]:
                return .success(output: "Logged in")
            case ["--diagnostic-once"]:
                return .success(output: "host=found app_server=found accessibility=granted")
            default:
                return .success()
            }
        })
    }

    private var installerOwnedMarketplaceJSON: String {
        #"{"marketplaces":[{"name":"codex-usage-sidebar","root":"\#(paths.stableMarketplaceRoot.path)"}]}"#
    }

    private var uninstallCommandArguments: [[String]] {
        [
            ["plugin", "marketplace", "list", "--json"],
            ["plugin", "remove", InstallerCommandPlan.pluginSelector, "--json"],
            ["plugin", "marketplace", "remove", InstallerCommandPlan.marketplaceName],
            ["uninstall"],
        ]
    }

    private var paths: InstallerPaths {
        Self.paths
    }

    private static let paths = InstallerPaths(
        homeDirectory: URL(fileURLWithPath: "/tmp/cus-view-model-home"),
        payloadRoot: URL(fileURLWithPath: "/tmp/cus-view-model-payload"),
        codexExecutable: URL(fileURLWithPath: "/tmp/cus-view-model-codex")
    )
}

private enum FixtureError: Error {
    case corruptPayload
}

private final class CommandHarness: @unchecked Sendable {
    private let lock = NSLock()
    private var queuedResults: [CommandResult]
    private let handler: (@Sendable (CommandSpec) -> CommandResult)?
    private var recordedCommands: [CommandSpec] = []

    init(results: [CommandResult]) {
        queuedResults = results
        handler = nil
    }

    init(handler: @escaping @Sendable (CommandSpec) -> CommandResult) {
        queuedResults = []
        self.handler = handler
    }

    var commands: [CommandSpec] {
        lock.withLock { recordedCommands }
    }

    func run(_ command: CommandSpec) throws -> CommandResult {
        lock.withLock {
            recordedCommands.append(command)
            if let handler {
                return handler(command)
            }
            precondition(!queuedResults.isEmpty, "unexpected command: \(command)")
            return queuedResults.removeFirst()
        }
    }
}

private extension CommandResult {
    static func success(output: String = "") -> CommandResult {
        CommandResult(terminationStatus: 0, standardOutput: output, standardError: "")
    }

    static func failure(error: String) -> CommandResult {
        CommandResult(terminationStatus: 1, standardOutput: "", standardError: error)
    }
}
