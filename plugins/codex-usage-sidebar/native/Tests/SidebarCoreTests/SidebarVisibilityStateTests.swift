import XCTest
@testable import SidebarCore

final class SidebarVisibilityStateTests: XCTestCase {
    func testToggleMovesBetweenSidebarAndTitlebar() {
        var state = SidebarVisibilityState(hostIdentity: "a")

        XCTAssertEqual(state.placement, .sidebar)
        state.toggle()
        XCTAssertEqual(state.placement, .titlebar)
        state.toggle()
        XCTAssertEqual(state.placement, .sidebar)
    }

    func testSameHostPreservesCollapsedState() {
        var state = SidebarVisibilityState(hostIdentity: "a")
        state.toggle()

        state.observeHost("a")

        XCTAssertEqual(state.placement, .titlebar)
    }

    func testNewHostPreservesLastKnownPlacement() {
        var state = SidebarVisibilityState(hostIdentity: "a")
        state.toggle()

        state.observeHost("b")

        XCTAssertEqual(state.placement, .titlebar)
        XCTAssertEqual(state.hostIdentity, "b")
    }

    func testObservedPlacementAuthoritativelySynchronizesState() {
        var state = SidebarVisibilityState(hostIdentity: "a")

        XCTAssertTrue(state.observePlacement(.titlebar))
        XCTAssertEqual(state.placement, .titlebar)
        XCTAssertFalse(state.observePlacement(.titlebar))
        XCTAssertTrue(state.observePlacement(.sidebar))
        XCTAssertEqual(state.placement, .sidebar)
    }
}
