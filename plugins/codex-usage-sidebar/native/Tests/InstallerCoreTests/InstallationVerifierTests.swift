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
            statusOutput: "pid=none version=0.2.2",
            expectedVersion: "0.2.3",
            commandSucceeded: false
        )

        XCTAssertFalse(report.isHealthy)
        XCTAssertEqual(
            Set(report.issues),
            Set([.statusCommandFailed, .managedProcessMissing, .versionMismatch, .runtimeStateMissing])
        )
    }

    func testForegroundInstallerMayObserveAHealthyHiddenRuntime() {
        let report = InstallationVerifier.evaluate(
            statusOutput: "pid=42 version=0.2.3 runtime=hidden placement=content-header",
            expectedVersion: "0.2.3",
            commandSucceeded: true
        )

        XCTAssertTrue(report.isHealthy)
    }

    func testMarketplaceInspectionRecognizesOnlyTheNamedMarketplace() throws {
        let personalMarketplaceRoot = "/" + "Users/test"
        let configured = """
        {"marketplaces":[{"name":"personal","root":"\(personalMarketplaceRoot)"},{"name":"codex-usage-sidebar","root":"/tmp/sidebar-marketplace"}]}
        """
        let unrelated = """
        {"marketplaces":[{"name":"personal"}]}
        """

        XCTAssertTrue(try MarketplaceInspector.containsSidebarMarketplace(in: configured))
        XCTAssertFalse(try MarketplaceInspector.containsSidebarMarketplace(in: unrelated))
        XCTAssertEqual(
            try MarketplaceInspector.sidebarMarketplaceRoot(in: configured),
            "/tmp/sidebar-marketplace"
        )
        XCTAssertNil(try MarketplaceInspector.sidebarMarketplaceRoot(in: unrelated))
    }
}
