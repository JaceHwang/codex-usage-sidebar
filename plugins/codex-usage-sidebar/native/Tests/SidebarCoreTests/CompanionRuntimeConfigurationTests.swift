import Foundation
import XCTest
@testable import SidebarCore

final class CompanionRuntimeConfigurationTests: XCTestCase {
    func testPluginDataArgumentDerivesSiblingCodexHome() {
        let configuration = CompanionRuntimeConfiguration(
            arguments: [
                "CodexUsageSidebar",
                "--plugin-data",
                "/tmp/CodexUsageSidebar/Data"
            ],
            userHomeURL: URL(fileURLWithPath: "/tmp/test-home")
        )

        XCTAssertEqual(
            configuration.pluginDataURL.path,
            "/tmp/CodexUsageSidebar/Data"
        )
        XCTAssertEqual(
            configuration.codexHomeURL.path,
            "/tmp/CodexUsageSidebar/CodexHome"
        )
    }

    func testMissingPluginDataUsesApplicationSupportDefault() {
        let configuration = CompanionRuntimeConfiguration(
            arguments: ["CodexUsageSidebar"],
            userHomeURL: URL(fileURLWithPath: "/tmp/test-home")
        )

        XCTAssertEqual(
            configuration.pluginDataURL.path,
            "/tmp/test-home/Library/Application Support/CodexUsageSidebar/Data"
        )
    }
}
