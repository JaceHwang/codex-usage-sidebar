import Foundation
import XCTest
@testable import InstallerCore

final class PayloadInstallerTests: XCTestCase {
    func testPayloadInstallAtomicallyCopiesTheVersionedMarketplace() throws {
        let fixture = try PayloadFixture.make(version: "0.2.3+codex.release")
        defer { fixture.cleanup() }

        try PayloadInstaller().install(from: fixture.payloadRoot, to: fixture.paths)

        let manifest = try String(contentsOf: fixture.paths.pluginManifest, encoding: .utf8)
        XCTAssertTrue(manifest.contains("0.2.3+codex.release"))
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: fixture.paths.controlScript.path))
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: fixture.paths.installRoot.appendingPathComponent(".Marketplace.previous").path
            )
        )
    }

    func testPayloadInstallRejectsAnyOtherBaseVersionWithoutReplacingExistingPayload() throws {
        let fixture = try PayloadFixture.make(version: "0.2.4")
        defer { fixture.cleanup() }
        try FileManager.default.createDirectory(
            at: fixture.paths.stableMarketplaceRoot,
            withIntermediateDirectories: true
        )
        let marker = fixture.paths.stableMarketplaceRoot.appendingPathComponent("keep.txt")
        try Data("existing".utf8).write(to: marker)

        XCTAssertThrowsError(
            try PayloadInstaller().install(from: fixture.payloadRoot, to: fixture.paths)
        )
        XCTAssertEqual(try String(contentsOf: marker, encoding: .utf8), "existing")
    }
}

private struct PayloadFixture {
    let root: URL
    let payloadRoot: URL
    let paths: InstallerPaths

    static func make(version: String) throws -> PayloadFixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("cus-payload-tests-\(UUID().uuidString)", isDirectory: true)
        let home = root.appendingPathComponent("home", isDirectory: true)
        let payload = root.appendingPathComponent("payload", isDirectory: true)
        let plugin = payload
            .appendingPathComponent("plugins", isDirectory: true)
            .appendingPathComponent("codex-usage-sidebar", isDirectory: true)
        let manifest = plugin
            .appendingPathComponent(".codex-plugin", isDirectory: true)
            .appendingPathComponent("plugin.json")
        let control = plugin
            .appendingPathComponent("scripts", isDirectory: true)
            .appendingPathComponent("sidebar-control.sh")
        try FileManager.default.createDirectory(
            at: manifest.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: control.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("{\"name\":\"codex-usage-sidebar\",\"version\":\"\(version)\"}".utf8)
            .write(to: manifest)
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: control)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: control.path
        )
        let marketplace = payload
            .appendingPathComponent(".agents/plugins", isDirectory: true)
            .appendingPathComponent("marketplace.json")
        try FileManager.default.createDirectory(
            at: marketplace.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("{\"name\":\"codex-usage-sidebar\",\"plugins\":[]}".utf8)
            .write(to: marketplace)

        return PayloadFixture(
            root: root,
            payloadRoot: payload,
            paths: InstallerPaths(
                homeDirectory: home,
                payloadRoot: payload,
                codexExecutable: URL(fileURLWithPath: "/usr/local/bin/codex")
            )
        )
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
    }
}
