import XCTest
@testable import InstallerCore

final class InstallationVerifierTests: XCTestCase {
    func testVerificationRequiresMatchingVersionManagedPIDAndVisibleRuntime() {
        let report = InstallationVerifier.evaluate(
            statusOutput: "pid=42 version=0.2.3 runtime=shown placement=content-header",
            expectedVersion: "0.2.3",
            commandSucceeded: true
        )

        XCTAssertTrue(report.isHealthy)
        XCTAssertEqual(report.pid, 42)
        XCTAssertEqual(report.version, "0.2.3")
    }

    func testVerificationReportsEveryMissingHealthSignal() {
        let report = InstallationVerifier.evaluate(
            statusOutput: "pid=none version=0.2.2 runtime=hidden",
            expectedVersion: "0.2.3",
            commandSucceeded: false
        )

        XCTAssertFalse(report.isHealthy)
        XCTAssertEqual(
            Set(report.issues),
            Set([.statusCommandFailed, .managedProcessMissing, .versionMismatch, .runtimeNotShown])
        )
    }

    func testMarketplaceInspectionRecognizesOnlyTheNamedMarketplace() throws {
        let configured = """
        {"marketplaces":[{"name":"personal"},{"name":"codex-usage-sidebar"}]}
        """
        let unrelated = """
        {"marketplaces":[{"name":"personal"}]}
        """

        XCTAssertTrue(try MarketplaceInspector.containsSidebarMarketplace(in: configured))
        XCTAssertFalse(try MarketplaceInspector.containsSidebarMarketplace(in: unrelated))
    }
}
