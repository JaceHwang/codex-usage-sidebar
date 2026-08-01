import XCTest
@testable import SidebarCore

final class AccessibilityPolicyTests: XCTestCase {
    func testNeverPromptsForAccessibilityAutomatically() {
        XCTAssertFalse(
            AccessibilityTrustPolicy.shouldPromptAutomatically
        )
    }
}
