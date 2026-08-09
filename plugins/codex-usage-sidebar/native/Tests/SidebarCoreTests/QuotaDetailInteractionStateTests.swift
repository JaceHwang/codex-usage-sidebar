import SidebarCore
import XCTest

final class QuotaDetailInteractionStateTests: XCTestCase {
    func testHoverShowsOnEntryAndHidesOnExit() {
        var state = QuotaDetailInteractionState()

        XCTAssertFalse(state.shouldShowDetail)

        state.updatePointerInside(true)
        XCTAssertTrue(state.shouldShowDetail)

        state.updatePointerInside(false)
        XCTAssertFalse(state.shouldShowDetail)
    }

    func testPinnedDetailRemainsVisibleAfterPointerLeaves() {
        var state = QuotaDetailInteractionState()
        state.updatePointerInside(true)

        state.togglePinned(pointerInside: true)
        state.updatePointerInside(false)

        XCTAssertTrue(state.isPinned)
        XCTAssertTrue(state.shouldShowDetail)
    }

    func testSecondClickDismissesUntilPointerExitsAndReenters() {
        var state = QuotaDetailInteractionState()
        state.updatePointerInside(true)
        state.togglePinned(pointerInside: true)

        state.togglePinned(pointerInside: true)

        XCTAssertFalse(state.isPinned)
        XCTAssertFalse(state.shouldShowDetail)

        state.updatePointerInside(true)
        XCTAssertFalse(state.shouldShowDetail)

        state.updatePointerInside(false)
        XCTAssertFalse(state.shouldShowDetail)

        state.updatePointerInside(true)
        XCTAssertTrue(state.shouldShowDetail)
    }

    func testResetClearsPinnedAndHoverState() {
        var state = QuotaDetailInteractionState()
        state.updatePointerInside(true)
        state.togglePinned(pointerInside: true)

        state.reset()

        XCTAssertFalse(state.isPinned)
        XCTAssertFalse(state.shouldShowDetail)
    }
}
