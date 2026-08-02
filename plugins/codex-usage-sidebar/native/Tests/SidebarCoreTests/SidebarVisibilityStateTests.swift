import XCTest
@testable import SidebarCore

final class SidebarVisibilityStateTests: XCTestCase {
    func testInitialPlacementIsAlwaysTitlebar() {
        let state = SidebarVisibilityState(hostIdentity: "a")
        let restoredSidebarState = SidebarVisibilityState(
            hostIdentity: "a",
            placement: .sidebar
        )

        XCTAssertEqual(state.placement, .titlebar)
        XCTAssertEqual(restoredSidebarState.placement, .titlebar)
    }

    func testToggleNeverMovesControlOutOfTitlebar() {
        var state = SidebarVisibilityState(hostIdentity: "a")

        state.toggle()
        XCTAssertEqual(state.placement, .titlebar)
        state.toggle()
        XCTAssertEqual(state.placement, .titlebar)
    }

    func testHostChangesPreserveTitlebarPlacement() {
        var state = SidebarVisibilityState(hostIdentity: "a")

        state.observeHost("a")
        XCTAssertEqual(state.placement, .titlebar)
        state.observeHost("b")
        XCTAssertEqual(state.placement, .titlebar)
        XCTAssertEqual(state.hostIdentity, "b")
    }

    func testObservedSidebarNeverMovesControlOutOfTitlebar() {
        var state = SidebarVisibilityState(hostIdentity: "a")

        XCTAssertFalse(state.observePlacement(.sidebar))
        XCTAssertEqual(state.placement, .titlebar)
        XCTAssertFalse(state.observePlacement(.titlebar))
        XCTAssertEqual(state.placement, .titlebar)
    }
}
