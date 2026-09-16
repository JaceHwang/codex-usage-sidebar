import CoreGraphics
import XCTest
@testable import SidebarCore

final class IndicatorPlacementTests: XCTestCase {
    private let visibleFrame = CGRect(x: 100, y: 50, width: 1_200, height: 800)
    private let indicatorSize = CGSize(width: 164, height: 46)

    func testDefaultsToAutomaticWithoutManualPlacements() {
        XCTAssertEqual(IndicatorPlacementPreferences().mode, .automatic)
        XCTAssertNil(
            IndicatorPlacementPreferences().placement(for: "display-a")
        )
    }

    func testStoresManualOriginNormalizedToVisibleScreen() {
        let frame = CGRect(x: 700, y: 350, width: 164, height: 46)
        let placement = IndicatorManualPlacement(
            frame: frame,
            in: visibleFrame
        )

        XCTAssertEqual(placement.normalizedX, 600 / 1_036, accuracy: 0.0001)
        XCTAssertEqual(placement.normalizedY, 300 / 754, accuracy: 0.0001)

        let resized = placement.resolvedFrame(
            in: CGRect(x: 0, y: 0, width: 2_400, height: 1_600),
            size: indicatorSize
        )
        XCTAssertEqual(resized.minX, 1_294.9807, accuracy: 0.001)
        XCTAssertEqual(resized.minY, 618.3024, accuracy: 0.001)
        XCTAssertEqual(resized.size, indicatorSize)
    }

    func testManualFrameClampsFullyInsideVisibleFrame() {
        let placement = IndicatorManualPlacement(
            normalizedX: 1,
            normalizedY: 1
        )

        XCTAssertEqual(
            placement.resolvedFrame(in: visibleFrame, size: indicatorSize),
            CGRect(x: 1_136, y: 804, width: 164, height: 46)
        )
    }

    func testSwitchingToManualCapturesCurrentAutomaticFrameForDisplay() {
        var preferences = IndicatorPlacementPreferences()
        let frame = CGRect(x: 900, y: 600, width: 164, height: 46)

        preferences.captureManualPlacement(
            frame: frame,
            visibleFrame: visibleFrame,
            displayID: "display-a"
        )
        preferences.mode = .free

        XCTAssertEqual(preferences.mode, .free)
        XCTAssertEqual(preferences.activeManualDisplayID, "display-a")
        XCTAssertEqual(
            preferences.placement(for: "display-a")?.resolvedFrame(
                in: visibleFrame,
                size: indicatorSize
            ),
            frame
        )
        XCTAssertNil(preferences.placement(for: "display-b"))
    }

    func testDecodesExistingPreferencesWithoutNewActiveDisplayField() throws {
        let data = Data("{\"mode\":\"locked\",\"placements\":{}}".utf8)
        let preferences = try JSONDecoder().decode(
            IndicatorPlacementPreferences.self,
            from: data
        )

        XCTAssertEqual(preferences.mode, .locked)
        XCTAssertNil(preferences.activeManualDisplayID)
    }

    func testAutomaticUsesCurrentAnchorWhileManualUsesStoredFrame() {
        let automaticFrame = CGRect(x: 860, y: 804, width: 164, height: 46)
        let manualFrame = CGRect(x: 210, y: 120, width: 164, height: 46)
        var preferences = IndicatorPlacementPreferences()
        preferences.captureManualPlacement(
            frame: manualFrame,
            visibleFrame: visibleFrame,
            displayID: "display-a"
        )

        XCTAssertEqual(
            IndicatorPlacementResolver.frame(
                preferences: preferences,
                automaticFrame: automaticFrame,
                displayID: "display-a",
                visibleFrame: visibleFrame
            ),
            automaticFrame
        )

        preferences.mode = .locked
        XCTAssertEqual(
            IndicatorPlacementResolver.frame(
                preferences: preferences,
                automaticFrame: automaticFrame,
                displayID: "display-a",
                visibleFrame: visibleFrame
            ),
            manualFrame
        )
    }

    func testOnlyFreeModeBeginsDragAfterDeliberateThreshold() {
        let origin = CGPoint(x: 10, y: 10)

        XCTAssertFalse(
            IndicatorPointerInteraction.beginsDrag(
                mode: .free,
                origin: origin,
                current: CGPoint(x: 12, y: 12)
            )
        )
        XCTAssertTrue(
            IndicatorPointerInteraction.beginsDrag(
                mode: .free,
                origin: origin,
                current: CGPoint(x: 14, y: 10)
            )
        )
        XCTAssertFalse(
            IndicatorPointerInteraction.beginsDrag(
                mode: .locked,
                origin: origin,
                current: CGPoint(x: 30, y: 30)
            )
        )
        XCTAssertFalse(
            IndicatorPointerInteraction.beginsDrag(
                mode: .automatic,
                origin: origin,
                current: CGPoint(x: 30, y: 30)
            )
        )
    }

    func testFreeDragSessionEmitsEveryPointerDeltaAfterThreshold() {
        var session = IndicatorDragSession()
        let origin = CGPoint(x: 100, y: 100)

        session.begin(at: origin)

        XCTAssertNil(
            session.update(
                to: CGPoint(x: 102, y: 102),
                mode: .free
            )
        )
        XCTAssertEqual(
            session.update(
                to: CGPoint(x: 106, y: 100),
                mode: .free
            ),
            CGPoint(x: 6, y: 0)
        )
        XCTAssertEqual(
            session.update(
                to: CGPoint(x: 148, y: 132),
                mode: .free
            ),
            CGPoint(x: 48, y: 32)
        )
        XCTAssertTrue(session.end())
        XCTAssertFalse(session.isDragging)
    }

    func testPositionMenuDoesNotDismissFromTheOpeningPointerEvent() {
        var state = PositionModeMenuDismissalState()

        state.beginPresentation()

        XCTAssertFalse(state.shouldDismissForOutsidePointerEvent)

        state.finishOpeningGesture()

        XCTAssertTrue(state.shouldDismissForOutsidePointerEvent)
    }
}
