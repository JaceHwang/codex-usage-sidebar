import CoreGraphics
import XCTest
@testable import SidebarCore

final class OverlayLayoutTests: XCTestCase {
    private let window = CGRect(x: 72, y: 72, width: 1_848, height: 1_049)

    func testIndicatorAlignsBeforeResolvedContentEdge() {
        XCTAssertEqual(
            OverlayLayout.indicatorFrame(
                in: window,
                contentTrailingEdge: 1_604
            ),
            CGRect(x: 1_448, y: 1_075, width: 148, height: 46)
        )
    }

    func testIndicatorKeepsExactGapAcrossMovingOpenLocationAnchors() {
        let anchors: [CGFloat] = [1_140, 1_420, 1_696, 1_810]

        for anchor in anchors {
            let frame = OverlayLayout.indicatorFrame(
                in: window,
                contentTrailingEdge: anchor
            )

            XCTAssertEqual(anchor - frame.maxX, OverlayLayout.indicatorGap)
        }
    }

    func testIndicatorKeepsExactGapWhenWindowMovesAndResizes() {
        let layouts = [
            (CGRect(x: 0, y: 0, width: 900, height: 700), CGFloat(760)),
            (CGRect(x: 120, y: 80, width: 1_200, height: 820), CGFloat(1_180)),
            (CGRect(x: 40, y: 20, width: 1_800, height: 1_040), CGFloat(1_700)),
        ]

        for (windowFrame, anchor) in layouts {
            let frame = OverlayLayout.indicatorFrame(
                in: windowFrame,
                contentTrailingEdge: anchor
            )

            XCTAssertEqual(anchor - frame.maxX, OverlayLayout.indicatorGap)
        }
    }

    func testIndicatorUsesTrailingFallbackWithoutResolvedAnchor() {
        XCTAssertEqual(
            OverlayLayout.indicatorFrame(
                in: window,
                contentTrailingEdge: nil
            ),
            CGRect(x: 1_596, y: 1_075, width: 148, height: 46)
        )
    }

    func testIndicatorStaysInsideSmallWindow() {
        let smallWindow = CGRect(x: 20, y: 30, width: 180, height: 80)
        let frame = OverlayLayout.indicatorFrame(
            in: smallWindow,
            contentTrailingEdge: 40
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

    func testControlSurfaceIsThirtyPointsAndCentered() {
        let indicator = CGRect(x: 0, y: 0, width: 148, height: 46)
        let surface = OverlayLayout.controlSurfaceFrame(in: indicator)

        XCTAssertEqual(surface, CGRect(x: 0, y: 8, width: 148, height: 30))
        XCTAssertEqual(surface.midY, indicator.midY)
    }
}
