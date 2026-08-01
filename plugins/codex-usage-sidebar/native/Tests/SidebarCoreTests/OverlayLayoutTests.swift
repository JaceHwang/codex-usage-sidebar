import CoreGraphics
import XCTest
@testable import SidebarCore

final class OverlayLayoutTests: XCTestCase {
    private let window = CGRect(x: 72, y: 1, width: 1_847, height: 1_048)

    func testExpandedIndicatorUsesCurrentOfficialFooterGeometry() {
        XCTAssertEqual(
            OverlayLayout.indicatorFrame(in: window, placement: .sidebar),
            CGRect(x: 192, y: 1, width: 147, height: 46)
        )
    }

    func testCollapsedIndicatorAlignsBeforeRightTitlebarControls() {
        XCTAssertEqual(
            OverlayLayout.titlebarIndicatorFrame(
                in: window,
                rightControlsLeadingEdge: 1_748
            ),
            CGRect(x: 1_592, y: 1_003, width: 148, height: 46)
        )
    }

    func testCollapsedIndicatorUsesTrailingFallbackWithoutTitlebarControls() {
        XCTAssertEqual(
            OverlayLayout.titlebarIndicatorFrame(
                in: window,
                rightControlsLeadingEdge: nil
            ),
            CGRect(x: 1_595, y: 1_003, width: 148, height: 46)
        )
    }

    func testCollapsedIndicatorStaysInsideSmallWindow() {
        let smallWindow = CGRect(x: 20, y: 30, width: 180, height: 80)
        let frame = OverlayLayout.titlebarIndicatorFrame(
            in: smallWindow,
            rightControlsLeadingEdge: 40
        )

        XCTAssertGreaterThanOrEqual(frame.minX, smallWindow.minX)
        XCTAssertLessThanOrEqual(frame.maxX, smallWindow.maxX)
    }

    func testTextFrameIsVerticallyCenteredInsideIndicator() {
        let indicator = CGRect(x: 0, y: 0, width: 148, height: 46)

        let text = OverlayLayout.centeredTextFrame(
            in: indicator,
            intrinsicHeight: 16,
            horizontalInset: 6
        )

        XCTAssertEqual(text, CGRect(x: 6, y: 15, width: 136, height: 16))
        XCTAssertEqual(text.midY, indicator.midY)
    }

    func testControlSurfaceIsThirtyPointsAndCenteredInFooter() {
        let indicator = CGRect(x: 0, y: 0, width: 148, height: 46)

        let surface = OverlayLayout.controlSurfaceFrame(in: indicator)

        XCTAssertEqual(surface, CGRect(x: 0, y: 8, width: 148, height: 30))
        XCTAssertEqual(surface.midY, indicator.midY)
    }

    func testSidebarRowUsesOfficialPaddingAndClamp() {
        XCTAssertEqual(
            OverlayLayout.sidebarRowFrame(in: window),
            CGRect(x: 80, y: 1, width: 259, height: 46)
        )
    }

    func testSidebarIndicatorReservesIndependentProfileIdentitySpace() {
        let row = OverlayLayout.sidebarRowFrame(in: window)
        let indicator = OverlayLayout.sidebarIndicatorFrame(in: row)

        XCTAssertGreaterThanOrEqual(indicator.minX - row.minX, 112)
        XCTAssertEqual(indicator.maxX, row.maxX)
    }

}
