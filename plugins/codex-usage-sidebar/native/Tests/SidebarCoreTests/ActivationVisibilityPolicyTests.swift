import XCTest
@testable import SidebarCore

final class ActivationVisibilityPolicyTests: XCTestCase {
    private let host = "com.openai.codex"
    private let companion = "com.jace.codex-usage-sidebar"

    func testCodexActivationReconcilesTheOverlay() {
        XCTAssertEqual(
            ActivationVisibilityPolicy.decision(
                activatedBundleIdentifier: host,
                hostBundleIdentifier: host,
                companionBundleIdentifier: companion
            ),
            .reconcileHost
        )
    }

    func testCompanionActivationPreservesTheVisibleOverlay() {
        XCTAssertEqual(
            ActivationVisibilityPolicy.decision(
                activatedBundleIdentifier: companion,
                hostBundleIdentifier: host,
                companionBundleIdentifier: companion
            ),
            .preserve
        )
    }

    func testAnotherApplicationActivationHidesTheOverlay() {
        XCTAssertEqual(
            ActivationVisibilityPolicy.decision(
                activatedBundleIdentifier: "com.apple.finder",
                hostBundleIdentifier: host,
                companionBundleIdentifier: companion
            ),
            .hide
        )
        XCTAssertEqual(
            ActivationVisibilityPolicy.decision(
                activatedBundleIdentifier: nil,
                hostBundleIdentifier: host,
                companionBundleIdentifier: companion
            ),
            .hide
        )
    }
}
