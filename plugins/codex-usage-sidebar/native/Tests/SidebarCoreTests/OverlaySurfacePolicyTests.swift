import XCTest
@testable import SidebarCore

final class OverlaySurfacePolicyTests: XCTestCase {
    func testRestUsesHostBackground() {
        XCTAssertEqual(
            OverlaySurfacePolicy.treatment(isIndicatorHovered: false),
            .hostBackground
        )
    }

    func testOnlyIndicatorHoverUsesQuotaEmphasis() {
        XCTAssertEqual(
            OverlaySurfacePolicy.treatment(isIndicatorHovered: true),
            .quotaHover
        )
    }
}
