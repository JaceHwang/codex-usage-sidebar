import Foundation
import XCTest
@testable import SidebarCore

final class HostDiscoveryTests: XCTestCase {
    private var testRoot: URL!

    override func setUpWithError() throws {
        testRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-host-discovery-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: testRoot,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: testRoot)
    }

    func testSelectionOrderPrefersRunningBundleThenApplicationsThenPath() throws {
        let running = try makeBundle(named: "Running.app", version: "1.2.3")
        let installed = try makeBundle(named: "Installed.app", version: "2.0.0")
        let pathDirectory = testRoot.appendingPathComponent("bin")
        let pathExecutable = try makeExecutable(
            at: pathDirectory.appendingPathComponent("codex"),
            contents: "path"
        )

        let runningResult = HostDiscovery(
            runningBundleURL: running,
            applicationBundleURL: installed,
            path: pathDirectory.path
        ).current()
        XCTAssertEqual(runningResult?.source, .runningBundle)
        XCTAssertEqual(
            runningResult?.appServerExecutableURL,
            running.appendingPathComponent("Contents/Resources/codex")
        )

        let installedResult = HostDiscovery(
            runningBundleURL: nil,
            applicationBundleURL: installed,
            path: pathDirectory.path
        ).current()
        XCTAssertEqual(installedResult?.source, .applicationsBundle)
        XCTAssertEqual(
            installedResult?.appServerExecutableURL,
            installed.appendingPathComponent("Contents/Resources/codex")
        )

        let missingBundle = testRoot.appendingPathComponent("Missing.app")
        let pathResult = HostDiscovery(
            runningBundleURL: nil,
            applicationBundleURL: missingBundle,
            path: pathDirectory.path
        ).current()
        XCTAssertEqual(pathResult?.source, .path)
        XCTAssertEqual(pathResult?.appServerExecutableURL, pathExecutable)
    }

    func testBuildIdentityIncludesBundleVersionAndExecutableMetadata() throws {
        let bundle = try makeBundle(named: "Running.app", version: "26.721.41059")
        let executable = bundle.appendingPathComponent("Contents/Resources/codex")
        let first = try XCTUnwrap(
            HostDiscovery(
                runningBundleURL: bundle,
                applicationBundleURL: bundle,
                path: ""
            ).current()
        )
        XCTAssertTrue(first.buildIdentity.contains("26.721.41059"))

        try Data("changed-size".utf8).write(to: executable)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executable.path
        )
        let second = try XCTUnwrap(
            HostDiscovery(
                runningBundleURL: bundle,
                applicationBundleURL: bundle,
                path: ""
            ).current()
        )

        XCTAssertNotEqual(first.buildIdentity, second.buildIdentity)
    }

    private func makeBundle(named name: String, version: String) throws -> URL {
        let bundle = testRoot.appendingPathComponent(name)
        let resources = bundle.appendingPathComponent("Contents/Resources")
        try FileManager.default.createDirectory(
            at: resources,
            withIntermediateDirectories: true
        )
        let plist: [String: Any] = [
            "CFBundleIdentifier": "com.openai.codex",
            "CFBundleShortVersionString": version,
            "CFBundleVersion": "123"
        ]
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try plistData.write(
            to: bundle.appendingPathComponent("Contents/Info.plist")
        )
        _ = try makeExecutable(
            at: resources.appendingPathComponent("codex"),
            contents: "bundle-\(version)"
        )
        return bundle
    }

    @discardableResult
    private func makeExecutable(at url: URL, contents: String) throws -> URL {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(contents.utf8).write(to: url)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: url.path
        )
        return url
    }
}
