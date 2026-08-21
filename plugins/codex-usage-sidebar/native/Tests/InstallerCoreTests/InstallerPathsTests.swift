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

    func testCodexExecutableLocatorFindsAUserInstalledCliOnPath() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-usage-sidebar-cli-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let executable = root.appendingPathComponent("codex")
        FileManager.default.createFile(atPath: executable.path, contents: Data("#!/bin/sh\n".utf8))
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o755))],
            ofItemAtPath: executable.path
        )

        let located = CodexExecutableLocator.locate(
            environment: ["PATH": root.path],
            standardCandidates: []
        )

        XCTAssertEqual(located?.standardizedFileURL, executable.standardizedFileURL)
    }
}
