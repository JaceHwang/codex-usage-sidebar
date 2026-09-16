import CoreGraphics
import SidebarCore
import XCTest

final class AutomaticIndicatorCollisionTests: XCTestCase {
    private let window = CGRect(x: 0, y: 0, width: 1200, height: 800)

    private func item(_ x: CGFloat, _ width: CGFloat) -> ContentHeaderControl {
        ContentHeaderControl(frame: CGRect(x: x, y: 760, width: width, height: 32), labels: [])
    }

    func testFallbackAvoidsMoreAndShareButtons() throws {
        let buttons = [item(990, 32), item(1040, 32)]
        let frame = try XCTUnwrap(ContentHeaderAnchorResolver.collisionFreeIndicatorFrame(
            anchor: ContentHeaderAnchor(trailingEdge: nil, source: .fallback),
            controls: buttons, windowFrame: window, indicatorWidth: 280
        ))
        for button in buttons {
            XCTAssertFalse(frame.intersects(button.frame.insetBy(dx: -8, dy: 0)))
        }
    }

    func testRevalidatesCachedLabeledAnchorAgainstNewButton() throws {
        let button = item(950, 32)
        let frame = try XCTUnwrap(ContentHeaderAnchorResolver.collisionFreeIndicatorFrame(
            anchor: ContentHeaderAnchor(trailingEdge: 1040, source: .labeledControl),
            controls: [button], windowFrame: window, indicatorWidth: 280
        ))
        XCTAssertFalse(frame.intersects(button.frame.insetBy(dx: -8, dy: 0)))
    }

    func testNoRoomReturnsNilInsteadOfCoveringControls() {
        XCTAssertNil(ContentHeaderAnchorResolver.collisionFreeIndicatorFrame(
            anchor: ContentHeaderAnchor(trailingEdge: nil, source: .fallback),
            controls: [item(0, 1200)], windowFrame: window, indicatorWidth: 280
        ))
    }

    func testDoesNotMoveIntoUnscannedArea() {
        XCTAssertNil(ContentHeaderAnchorResolver.collisionFreeIndicatorFrame(
            anchor: ContentHeaderAnchor(trailingEdge: 500, source: .openLocation),
            controls: [item(850, 350)], windowFrame: window,
            indicatorWidth: 280, minimumScannedX: 700
        ))
    }

    func testPreservesSafePreferredPositionAndActualWidth() throws {
        let anchor = ContentHeaderAnchor(trailingEdge: 900, source: .openLocation)
        let frame = try XCTUnwrap(ContentHeaderAnchorResolver.collisionFreeIndicatorFrame(
            anchor: anchor, controls: [item(900, 100)], windowFrame: window, indicatorWidth: 280
        ))
        XCTAssertEqual(frame, OverlayLayout.indicatorFrame(in: window, contentTrailingEdge: 900, width: 280))
    }

    func testMenuButtonsAreToolbarObstacles() {
        for role in ["AXButton", "AXMenuButton", "AXPopUpButton"] {
            XCTAssertTrue(ContentHeaderAnchorResolver.isInteractiveToolbarRole(role))
        }
        XCTAssertFalse(ContentHeaderAnchorResolver.isInteractiveToolbarRole("AXGroup"))
    }

    func testAvoidsControlPartiallyCrossingToolbarBoundary() throws {
        let button = ContentHeaderControl(
            frame: CGRect(x: 990, y: 745, width: 32, height: 40), labels: []
        )
        let frame = try XCTUnwrap(ContentHeaderAnchorResolver.collisionFreeIndicatorFrame(
            anchor: ContentHeaderAnchor(trailingEdge: nil, source: .fallback),
            controls: [button], windowFrame: window, indicatorWidth: 280
        ))
        XCTAssertFalse(frame.intersects(button.frame.insetBy(dx: -8, dy: 0)))
    }
    func testOccupiedDefaultSwitchesToFreeAtDefaultFrame() {
        let result = ContentHeaderAnchorResolver.automaticPlacement(
            anchor: ContentHeaderAnchor(trailingEdge: nil, source: .fallback),
            controls: [item(0, 1200)], windowFrame: window, indicatorWidth: 280
        )
        XCTAssertTrue(result.shouldSwitchToFree)
        XCTAssertEqual(result.frame, OverlayLayout.indicatorFrame(in: window, contentTrailingEdge: nil, width: 280))
    }

    func testUnscannedButUnoccupiedDefaultKeepsAutomaticMode() {
        let result = ContentHeaderAnchorResolver.automaticPlacement(
            anchor: ContentHeaderAnchor(trailingEdge: nil, source: .fallback),
            controls: [], windowFrame: window, indicatorWidth: 280, minimumScannedX: 1100
        )
        XCTAssertFalse(result.shouldSwitchToFree)
        XCTAssertEqual(result.frame.width, 280)
    }

    func testFreeFallbackOverwritesOldManualPositionAndPersists() throws {
        var preferences = IndicatorPlacementPreferences()
        preferences.captureManualPlacement(frame: CGRect(x: 10, y: 10, width: 280, height: 46), visibleFrame: window, displayID: "test")
        let frame = OverlayLayout.indicatorFrame(in: window, contentTrailingEdge: nil, width: 280)
        preferences.switchToFreeFallback(frame: frame, visibleFrame: window, displayID: "test")
        let restored = try JSONDecoder().decode(IndicatorPlacementPreferences.self, from: JSONEncoder().encode(preferences))
        XCTAssertEqual(restored.mode, .free)
        XCTAssertEqual(IndicatorPlacementResolver.frame(preferences: restored, automaticFrame: frame, displayID: "test", visibleFrame: window), frame)
    }

    func testUnknownActionableControlIsObstacle() {
        XCTAssertTrue(ContentHeaderAnchorResolver.isInteractiveToolbarRole("AXCustomControl", actions: ["AXPress"]))
        XCTAssertTrue(ContentHeaderAnchorResolver.isInteractiveToolbarRole("AXCheckBox", actions: ["AXPress"]))
        XCTAssertFalse(ContentHeaderAnchorResolver.isInteractiveToolbarRole("AXGroup", actions: []))
    }

    func testAuxiliaryActionsDoNotMakeContainersOrImagesClickable() {
        for role in ["AXGroup", "AXImage", "AXStaticText"] {
            XCTAssertFalse(ContentHeaderAnchorResolver.isInteractiveToolbarRole(
                role, actions: ["AXShowMenu", "AXScrollToVisible"]
            ))
        }
    }

    func testCapturedFullWidthToolbarContainerDoesNotForceFreeMode() {
        let actualWindow = CGRect(x: 0, y: 0, width: 1920, height: 1049)
        let samples: [(String, [String], CGRect)] = [
            ("AXGroup", ["AXShowMenu", "AXScrollToVisible"], CGRect(x: 0, y: 1003, width: 1920, height: 46)),
            ("AXGroup", ["AXShowMenu", "AXScrollToVisible"], CGRect(x: 318, y: 1003, width: 1160, height: 46)),
            ("AXPopUpButton", ["AXPress", "AXShowMenu"], CGRect(x: 1340, y: 1012, width: 28, height: 28)),
            ("AXButton", ["AXPress"], CGRect(x: 1374, y: 1012, width: 64, height: 28)),
            ("AXCheckBox", ["AXPress"], CGRect(x: 1444, y: 1012, width: 28, height: 28))
        ]
        let controls = samples.filter {
            ContentHeaderAnchorResolver.isInteractiveToolbarRole($0.0, actions: $0.1)
        }.map { ContentHeaderControl(frame: $0.2, labels: []) }
        let result = ContentHeaderAnchorResolver.automaticPlacement(
            anchor: ContentHeaderAnchor(trailingEdge: 1340, source: .labeledControl),
            controls: controls, windowFrame: actualWindow, indicatorWidth: 212
        )
        XCTAssertFalse(result.shouldSwitchToFree)
        XCTAssertEqual(result.frame.minX, 1120)
    }

}
