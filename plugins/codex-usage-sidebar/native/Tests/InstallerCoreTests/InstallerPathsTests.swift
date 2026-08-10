import XCTest
@testable import InstallerCore

final class InstallerPathsTests: XCTestCase {
    func testInstallationPathsStayInsideSelectedHome() {
        let paths = InstallerPaths(
            homeDirectory: URL(fileURLWithPath: "/tmp/cus-installer-home"),
            payloadRoot: URL(fileURLWithPath: "/Volumes/Codex Usage Sidebar/payload"),
            codexExecutable: URL(fileURLWithPath: "/usr/local/bin/codex")
        )

        XCTAssertEqual(
            paths.installRoot.path,
            "/tmp/cus-installer-home/Library/Application Support/CodexUsageSidebar"
        )
        XCTAssertTrue(
            paths.stableMarketplaceRoot.path.hasPrefix(paths.installRoot.path + "/")
        )
        XCTAssertEqual(
            paths.pluginManifest.path,
            paths.pluginRoot
                .appendingPathComponent(".codex-plugin/plugin.json", isDirectory: false)
                .path
        )
        XCTAssertEqual(
            paths.runtimeState.path,
            paths.pluginData.appendingPathComponent("runtime-state.txt").path
        )
    }
}
