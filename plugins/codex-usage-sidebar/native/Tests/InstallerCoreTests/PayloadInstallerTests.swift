import CryptoKit
import Foundation
import XCTest
@testable import InstallerCore

final class PayloadInstallerTests: XCTestCase {
    func testPayloadInstallAtomicallyCopiesTheVersionedMarketplace() throws {
        let fixture = try PayloadFixture.make(version: "0.3.2+codex.release")
        defer { fixture.cleanup() }

        try PayloadInstaller().install(from: fixture.payloadRoot, to: fixture.paths)

        let manifest = try String(contentsOf: fixture.paths.pluginManifest, encoding: .utf8)
        XCTAssertTrue(manifest.contains("0.3.2+codex.release"))
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: fixture.paths.controlScript.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.previous.path))
        XCTAssertEqual(
            try String(contentsOf: fixture.paths.pluginRoot.appendingPathComponent("marker.txt")),
            "primary"
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

    func testPayloadInstallRejectsSymlinkedInstallAncestorWithoutWritingOutsideHome() throws {
        let fixture = try PayloadFixture.make()
        defer { fixture.cleanup() }
        let outside = fixture.root.appendingPathComponent("outside", isDirectory: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: fixture.paths.installRoot.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createSymbolicLink(
            at: fixture.paths.installRoot,
            withDestinationURL: outside
        )

        XCTAssertThrowsError(
            try PayloadInstaller().install(from: fixture.payloadRoot, to: fixture.paths)
        ) { error in
            XCTAssertEqual(error as? PayloadInstallerError, .unsafeDestination)
        }
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: outside.appendingPathComponent("Marketplace").path
            )
        )
    }

    func testPayloadInstallRejectsProvenanceDigestMismatch() throws {
        let fixture = try PayloadFixture.make()
        defer { fixture.cleanup() }
        try fixture.writeProvenance(digest: String(repeating: "0", count: 64))

        XCTAssertThrowsError(
            try PayloadInstaller().install(from: fixture.payloadRoot, to: fixture.paths)
        ) { error in
            XCTAssertEqual(error as? PayloadInstallerError, .companionDigestMismatch)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.paths.stableMarketplaceRoot.path))
    }

    func testPayloadInstallRejectsMarketplaceManifestThatRedirectsThePlugin() throws {
        let fixture = try PayloadFixture.make()
        defer { fixture.cleanup() }
        let marketplace = fixture.payloadRoot.appendingPathComponent(
            ".agents/plugins/marketplace.json"
        )
        try Data(
            #"{"name":"codex-usage-sidebar","plugins":[{"name":"codex-usage-sidebar","source":{"source":"local","path":"../external"}}]}"#.utf8
        ).write(to: marketplace)

        XCTAssertThrowsError(
            try PayloadInstaller().install(from: fixture.payloadRoot, to: fixture.paths)
        ) { error in
            XCTAssertEqual(error as? PayloadInstallerError, .invalidMarketplaceManifest)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.paths.stableMarketplaceRoot.path))
    }

    func testPayloadInstallRejectsInvalidCompanionSignature() throws {
        let fixture = try PayloadFixture.make()
        defer { fixture.cleanup() }
        let handle = try FileHandle(forWritingTo: fixture.companionExecutable)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("tampered".utf8))
        try handle.close()

        XCTAssertThrowsError(
            try PayloadInstaller().install(from: fixture.payloadRoot, to: fixture.paths)
        ) { error in
            XCTAssertEqual(error as? PayloadInstallerError, .invalidCompanionSignature)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.paths.stableMarketplaceRoot.path))
    }

    func testInterruptedSwapRestoresBackupBeforeValidatingTheNextPayload() throws {
        let fixture = try PayloadFixture.make()
        defer { fixture.cleanup() }
        try FileManager.default.createDirectory(at: fixture.previous, withIntermediateDirectories: true)
        let knownGood = fixture.previous.appendingPathComponent("known-good.txt")
        try Data("recover-me".utf8).write(to: knownGood)
        try fixture.writeProvenance(digest: String(repeating: "f", count: 64))

        XCTAssertThrowsError(
            try PayloadInstaller().install(from: fixture.payloadRoot, to: fixture.paths)
        )

        XCTAssertEqual(
            try String(
                contentsOf: fixture.paths.stableMarketplaceRoot
                    .appendingPathComponent("known-good.txt"),
                encoding: .utf8
            ),
            "recover-me"
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.previous.path))
    }

    func testConcurrentPayloadInstallsSerializeWithoutSharingStagingPaths() throws {
        let fixture = try PayloadFixture.make()
        defer { fixture.cleanup() }
        let alternate = fixture.root.appendingPathComponent("payload-alternate", isDirectory: true)
        try FileManager.default.copyItem(at: fixture.payloadRoot, to: alternate)
        try Data("alternate".utf8).write(
            to: alternate.appendingPathComponent("plugins/codex-usage-sidebar/marker.txt")
        )
        try Data(count: 8 * 1_024 * 1_024).write(
            to: fixture.payloadRoot.appendingPathComponent("copy-pressure.bin")
        )
        try Data(count: 8 * 1_024 * 1_024).write(
            to: alternate.appendingPathComponent("copy-pressure.bin")
        )
        let errors = LockedErrors()
        let paths = fixture.paths
        let primary = fixture.payloadRoot

        DispatchQueue.concurrentPerform(iterations: 2) { index in
            do {
                try PayloadInstaller().install(
                    from: index == 0 ? primary : alternate,
                    to: paths
                )
            } catch {
                errors.append(error)
            }
        }

        XCTAssertEqual(errors.count, 0, "concurrent errors: \(errors.values)")
        let marker = try String(
            contentsOf: fixture.paths.pluginRoot.appendingPathComponent("marker.txt"),
            encoding: .utf8
        )
        XCTAssertTrue(["primary", "alternate"].contains(marker))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.previous.path))
        let leftovers = try FileManager.default.contentsOfDirectory(
            atPath: fixture.paths.installRoot.path
        ).filter { $0.hasPrefix(".Marketplace.staging.") }
        XCTAssertEqual(leftovers, [])
    }
}

private struct PayloadFixture {
    let root: URL
    let payloadRoot: URL
    let paths: InstallerPaths

    var plugin: URL {
        payloadRoot.appendingPathComponent("plugins/codex-usage-sidebar", isDirectory: true)
    }

    var companionApp: URL {
        plugin.appendingPathComponent("assets/Codex Usage Sidebar.app", isDirectory: true)
    }

    var companionExecutable: URL {
        companionApp.appendingPathComponent("Contents/MacOS/CodexUsageSidebar")
    }

    var provenance: URL {
        plugin.appendingPathComponent("assets/PROVENANCE.json")
    }

    var previous: URL {
        paths.installRoot.appendingPathComponent(".Marketplace.previous", isDirectory: true)
    }

    static func make(
        version: String = "0.3.2+codex.release"
    ) throws -> PayloadFixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("cus-payload-tests-\(UUID().uuidString)", isDirectory: true)
        let home = root.appendingPathComponent("home", isDirectory: true)
        let payload = root.appendingPathComponent("payload", isDirectory: true)
        let plugin = payload.appendingPathComponent(
            "plugins/codex-usage-sidebar",
            isDirectory: true
        )
        let manifest = plugin.appendingPathComponent(".codex-plugin/plugin.json")
        let control = plugin.appendingPathComponent("scripts/sidebar-control.sh")
        let marketplace = payload.appendingPathComponent(".agents/plugins/marketplace.json")
        let app = plugin.appendingPathComponent(
            "assets/Codex Usage Sidebar.app",
            isDirectory: true
        )
        let executable = app.appendingPathComponent("Contents/MacOS/CodexUsageSidebar")
        try FileManager.default.createDirectory(
            at: manifest.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: control.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: marketplace.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: executable.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("{\"name\":\"codex-usage-sidebar\",\"version\":\"\(version)\"}".utf8)
            .write(to: manifest)
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: control)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: control.path
        )
        try Data(
            #"{"name":"codex-usage-sidebar","plugins":[{"name":"codex-usage-sidebar","source":{"source":"local","path":"./plugins/codex-usage-sidebar"}}]}"#.utf8
        )
            .write(to: marketplace)
        try FileManager.default.copyItem(
            at: URL(fileURLWithPath: "/usr/bin/true"),
            to: executable
        )
        let info = app.appendingPathComponent("Contents/Info.plist")
        let plist: [String: Any] = [
            "CFBundleExecutable": "CodexUsageSidebar",
            "CFBundleIdentifier": "com.jace.codex-usage-sidebar.fixture",
            "CFBundlePackageType": "APPL",
            "CFBundleShortVersionString": "0.3.2",
        ]
        try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        ).write(to: info)
        try runCodesign(app)
        try Data("primary".utf8).write(to: plugin.appendingPathComponent("marker.txt"))

        let fixture = PayloadFixture(
            root: root,
            payloadRoot: payload,
            paths: InstallerPaths(
                homeDirectory: home,
                payloadRoot: payload,
                codexExecutable: URL(fileURLWithPath: "/usr/local/bin/codex")
            )
        )
        try fixture.writeProvenance(digest: fixture.companionDigest)
        return fixture
    }

    var companionDigest: String {
        get throws {
            SHA256.hash(data: try Data(contentsOf: companionExecutable))
                .map { String(format: "%02x", $0) }
                .joined()
        }
    }

    func writeProvenance(digest: String) throws {
        let data: [String: Any] = [
            "schemaVersion": 1,
            "sourceCommit": String(repeating: "a", count: 40),
            "companion": ["executableSha256": digest, "signature": "adhoc"],
        ]
        try JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted, .sortedKeys])
            .write(to: provenance)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
    }

    private static func runCodesign(_ app: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["--force", "--sign", "-", app.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw FixtureError.codesignFailed
        }
    }
}

private final class LockedErrors: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Error] = []

    var values: [Error] {
        lock.withLock { storage }
    }

    var count: Int {
        lock.withLock { storage.count }
    }

    func append(_ error: Error) {
        lock.withLock { storage.append(error) }
    }
}

private enum FixtureError: Error {
    case codesignFailed
}
