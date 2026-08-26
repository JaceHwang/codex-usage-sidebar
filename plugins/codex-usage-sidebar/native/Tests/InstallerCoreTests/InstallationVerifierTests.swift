import XCTest
@testable import InstallerCore

final class InstallationVerifierTests: XCTestCase {
    func testVerificationRequiresAuthenticatedGrantedHealthyRuntimeEvidence() {
        let report = InstallationVerifier.evaluate(
            statusOutput: "pid=42 version=0.3.3 runtime=shown placement=content-header",
            expectedVersion: "0.3.3",
            statusCommandSucceeded: true,
            loginCommandSucceeded: true,
            accessibilityOutput: "host=found app_server=found accessibility=granted",
            accessibilityCommandSucceeded: true
        )

        XCTAssertTrue(report.isHealthy)
        XCTAssertEqual(report.pid, 42)
        XCTAssertEqual(report.version, "0.3.3")
    }

    func testVerificationReportsEveryMissingHealthSignal() {
        let report = InstallationVerifier.evaluate(
            statusOutput: "pid=none version=0.2.2",
            expectedVersion: "0.3.3",
            statusCommandSucceeded: false,
            loginCommandSucceeded: false,
            accessibilityOutput: "host=missing app_server=missing accessibility=required",
            accessibilityCommandSucceeded: false
        )

        XCTAssertFalse(report.isHealthy)
        XCTAssertEqual(
            Set(report.issues),
            Set([
                .statusCommandFailed,
                .managedProcessMissing,
                .versionMismatch,
                .runtimeStateMissing,
                .codexLoginMissing,
                .accessibilityCheckFailed,
                .accessibilityNotGranted,
                .codexHostMissing,
                .appServerMissing,
            ])
        )
    }

    func testVerificationRejectsUnauthenticatedIsolatedCodexHome() {
        let report = InstallationVerifier.evaluate(
            statusOutput: "pid=42 version=0.3.3 runtime=shown placement=content-header",
            expectedVersion: "0.3.3",
            statusCommandSucceeded: true,
            loginCommandSucceeded: false,
            accessibilityOutput: "host=found app_server=found accessibility=granted",
            accessibilityCommandSucceeded: true
        )

        XCTAssertFalse(report.isHealthy)
        XCTAssertTrue(report.issues.contains(.codexLoginMissing))
    }

    func testVerificationRejectsAccessibilityRequiredFromInstalledCompanion() {
        let report = InstallationVerifier.evaluate(
            statusOutput: "pid=42 version=0.3.3 runtime=shown placement=content-header",
            expectedVersion: "0.3.3",
            statusCommandSucceeded: true,
            loginCommandSucceeded: true,
            accessibilityOutput: "host=found app_server=found accessibility=required",
            accessibilityCommandSucceeded: true
        )

        XCTAssertFalse(report.isHealthy)
        XCTAssertTrue(report.issues.contains(.accessibilityNotGranted))
    }

    func testVerificationRejectsNoHostAndNoSnapshotStates() {
        let noHost = InstallationVerifier.evaluate(
            statusOutput: "pid=42 version=0.3.3 runtime=hidden:no-running-host",
            expectedVersion: "0.3.3",
            statusCommandSucceeded: true,
            loginCommandSucceeded: true,
            accessibilityOutput: "host=missing app_server=missing accessibility=unknown",
            accessibilityCommandSucceeded: true
        )
        let noSnapshot = InstallationVerifier.evaluate(
            statusOutput: "pid=42 version=0.3.3 runtime=hidden:no-snapshot",
            expectedVersion: "0.3.3",
            statusCommandSucceeded: true,
            loginCommandSucceeded: true,
            accessibilityOutput: "host=found app_server=found accessibility=granted",
            accessibilityCommandSucceeded: true
        )

        XCTAssertFalse(noHost.isHealthy)
        XCTAssertTrue(noHost.issues.contains(.codexHostMissing))
        XCTAssertFalse(noSnapshot.isHealthy)
        XCTAssertTrue(noSnapshot.issues.contains(.runtimeStateUnhealthy))
    }

    func testForegroundInstallerMayObserveLegitimateNotForegroundRuntime() {
        let report = InstallationVerifier.evaluate(
            statusOutput: "pid=42 version=0.3.3 runtime=hidden:not-foreground",
            expectedVersion: "0.3.3",
            statusCommandSucceeded: true,
            loginCommandSucceeded: true,
            accessibilityOutput: "host=found app_server=found accessibility=granted",
            accessibilityCommandSucceeded: true
        )

        XCTAssertTrue(report.isHealthy)
    }

    func testMarketplaceInspectionRecognizesOnlyTheNamedMarketplace() throws {
        let configured = """
        {"marketplaces":[{"name":"personal","root":"/tmp/personal"},{"name":"codex-usage-sidebar","root":"/tmp/sidebar-marketplace"}]}
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

    func testMarketplaceInspectionReusesOnlyTheCanonicalInstallerOwnedRoot() throws {
        let expectedRoot = URL(fileURLWithPath: "/tmp/sidebar/Marketplace")
        let exact = """
        {"marketplaces":[{"name":"codex-usage-sidebar","root":"/tmp/sidebar/./Marketplace"}]}
        """
        let external = """
        {"marketplaces":[{"name":"codex-usage-sidebar","root":"/tmp/external-marketplace"}]}
        """

        XCTAssertEqual(
            try MarketplaceInspector.configuration(in: exact, expectedRoot: expectedRoot),
            .installerOwned
        )
        XCTAssertEqual(
            try MarketplaceInspector.configuration(in: external, expectedRoot: expectedRoot),
            .conflict(root: "/tmp/external-marketplace")
        )
    }
}
