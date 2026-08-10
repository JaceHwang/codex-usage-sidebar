import XCTest
@testable import InstallerCore

final class CommandRunnerTests: XCTestCase {
    func testRunnerCapturesArgumentsOutputAndExitStatus() throws {
        let command = CommandSpec(
            executable: URL(fileURLWithPath: "/usr/bin/printf"),
            arguments: ["%s", "installer-ready"]
        )

        let result = try ProcessCommandRunner().run(command)

        XCTAssertEqual(result.terminationStatus, 0)
        XCTAssertEqual(result.standardOutput, "installer-ready")
        XCTAssertEqual(result.standardError, "")
        XCTAssertTrue(result.succeeded)
    }

    func testRunnerMergesOnlyExplicitEnvironmentValues() throws {
        let command = CommandSpec(
            executable: URL(fileURLWithPath: "/usr/bin/env"),
            arguments: [],
            environment: ["CUS_INSTALLER_TEST_VALUE": "isolated-home"]
        )

        let result = try ProcessCommandRunner().run(command)

        XCTAssertTrue(result.standardOutput.contains("CUS_INSTALLER_TEST_VALUE=isolated-home"))
        XCTAssertNotNil(result.environmentValue(named: "PATH"))
    }
}
