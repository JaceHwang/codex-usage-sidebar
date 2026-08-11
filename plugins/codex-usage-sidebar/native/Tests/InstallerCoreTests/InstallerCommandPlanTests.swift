import XCTest
@testable import InstallerCore

final class InstallerCommandPlanTests: XCTestCase {
    private let paths = InstallerPaths(
        homeDirectory: URL(fileURLWithPath: "/tmp/cus-installer-home"),
        payloadRoot: URL(fileURLWithPath: "/Volumes/Codex Usage Sidebar/payload"),
        codexExecutable: URL(fileURLWithPath: "/opt/homebrew/bin/codex")
    )

    func testInstallPlanAddsLocalMarketplaceBeforePluginAndCompanion() {
        let commands = InstallerCommandPlan.install(
            paths: paths,
            marketplaceAlreadyConfigured: false
        )

        XCTAssertEqual(commands.count, 3)
        XCTAssertEqual(commands[0].executable, paths.codexExecutable)
        XCTAssertEqual(
            commands[0].arguments,
            ["plugin", "marketplace", "add", paths.stableMarketplaceRoot.path, "--json"]
        )
        XCTAssertEqual(
            commands[1].arguments,
            ["plugin", "add", "codex-usage-sidebar@codex-usage-sidebar", "--json"]
        )
        XCTAssertEqual(commands[2].executable, paths.controlScript)
        XCTAssertEqual(
            commands[2].arguments,
            [
                "ensure",
                "--plugin-root", paths.pluginRoot.path,
                "--plugin-data", paths.pluginData.path,
            ]
        )
    }

    func testInstallPlanReusesConfiguredMarketplace() {
        let commands = InstallerCommandPlan.install(
            paths: paths,
            marketplaceAlreadyConfigured: true
        )

        XCTAssertEqual(commands.count, 2)
        XCTAssertEqual(
            commands[0].arguments,
            ["plugin", "add", "codex-usage-sidebar@codex-usage-sidebar", "--json"]
        )
    }

    func testLoginCommandsUseTheIsolatedCodexHome() {
        let status = InstallerCommandPlan.loginStatus(paths: paths)
        let login = InstallerCommandPlan.login(paths: paths)

        XCTAssertEqual(status.arguments, ["login", "status"])
        XCTAssertEqual(login.arguments, ["login"])
        XCTAssertEqual(status.environment["CODEX_HOME"], paths.codexHome.path)
        XCTAssertEqual(login.environment["CODEX_HOME"], paths.codexHome.path)
    }

    func testMarketplaceListUsesStructuredJSONOutput() {
        let command = InstallerCommandPlan.marketplaceList(paths: paths)

        XCTAssertEqual(command.executable, paths.codexExecutable)
        XCTAssertEqual(command.arguments, ["plugin", "marketplace", "list", "--json"])
    }

    func testAccessibilityCheckRunsThroughTheInstalledCompanionIdentity() {
        let command = InstallerCommandPlan.accessibilityStatus(paths: paths)

        XCTAssertEqual(command.executable, paths.installedCompanionExecutable)
        XCTAssertEqual(command.arguments, ["--diagnostic-once"])
    }

    func testPlansNeverEvaluateShellSource() {
        let commands = InstallerCommandPlan.install(
            paths: paths,
            marketplaceAlreadyConfigured: false
        ) + [
            InstallerCommandPlan.status(paths: paths),
            InstallerCommandPlan.repair(paths: paths),
            InstallerCommandPlan.loginStatus(paths: paths),
            InstallerCommandPlan.login(paths: paths),
            InstallerCommandPlan.accessibilityStatus(paths: paths),
        ] + InstallerCommandPlan.uninstall(paths: paths, removeMarketplace: true)

        XCTAssertFalse(commands.isEmpty)
        for command in commands {
            XCTAssertNotEqual(command.executable.path, "/bin/sh")
            XCTAssertNotEqual(command.executable.path, "/bin/zsh")
            XCTAssertFalse(command.arguments.contains("-c"))
        }
    }
}
