import CoreGraphics
import SidebarCore
import XCTest

final class ContentHeaderAnchorResolverTests: XCTestCase {
    private let window = CGRect(x: 72, y: 72, width: 1_848, height: 1_049)

    func testUsesOpenLocationInsteadOfUnrelatedContentControl() {
        let anchor = ContentHeaderAnchorResolver.resolve(
            controls: [
                control(x: 1_200, width: 28, labels: ["复制"]),
                control(x: 1_696, width: 91, labels: ["打开位置"]),
                control(x: 1_810, width: 28, labels: ["环境信息"]),
            ],
            paneFrames: [],
            windowFrame: window
        )

        XCTAssertEqual(anchor.trailingEdge, 1_696)
        XCTAssertEqual(anchor.source, .openLocation)
    }

    func testRecognizesEnglishOpenLocationIdentifier() {
        let anchor = ContentHeaderAnchorResolver.resolve(
            controls: [
                control(x: 1_696, width: 91, labels: ["open-location-button"]),
            ],
            paneFrames: [],
            windowFrame: window
        )

        XCTAssertEqual(anchor.trailingEdge, 1_696)
        XCTAssertEqual(anchor.source, .openLocation)
    }

    func testRightPaneBoundaryKeepsOverlayInsideCentralContent() {
        let anchor = ContentHeaderAnchorResolver.resolve(
            controls: [
                control(x: 1_866, y: 1_023, width: 28, labels: ["其他"]),
            ],
            paneFrames: [
                CGRect(x: 1_604, y: 84, width: 316, height: 978),
            ],
            windowFrame: window
        )

        XCTAssertEqual(anchor.trailingEdge, 1_604)
        XCTAssertEqual(anchor.source, .rightPaneBoundary)
    }

    func testRightPaneBoundaryOverridesOpenLocationInsideRightPane() {
        let anchor = ContentHeaderAnchorResolver.resolve(
            controls: [
                control(x: 1_696, width: 91, labels: ["打开位置"]),
                control(x: 1_810, width: 28, labels: ["其他"]),
            ],
            paneFrames: [
                CGRect(x: 1_604, y: 84, width: 316, height: 978),
            ],
            windowFrame: window
        )

        XCTAssertEqual(anchor.trailingEdge, 1_604)
        XCTAssertEqual(anchor.source, .rightPaneBoundary)
    }

    func testCentralOpenLocationRemainsPreferredBeforeRightPane() {
        let anchor = ContentHeaderAnchorResolver.resolve(
            controls: [
                control(x: 1_500, width: 91, labels: ["打开位置"]),
                control(x: 1_696, width: 91, labels: ["打开位置"]),
            ],
            paneFrames: [
                CGRect(x: 1_604, y: 84, width: 316, height: 978),
            ],
            windowFrame: window
        )

        XCTAssertEqual(anchor.trailingEdge, 1_500)
        XCTAssertEqual(anchor.source, .openLocation)
    }

    func testUsesRightmostWideLabeledControlAsSemanticFallback() {
        let anchor = ContentHeaderAnchorResolver.resolve(
            controls: [
                control(x: 1_200, width: 72, labels: ["Old action"]),
                control(x: 1_696, width: 91, labels: ["Renamed action"]),
                control(x: 1_810, width: 28, labels: ["Icon"]),
            ],
            paneFrames: [],
            windowFrame: window
        )

        XCTAssertEqual(anchor.trailingEdge, 1_696)
        XCTAssertEqual(anchor.source, .labeledControl)
    }

    func testOpenLocationAnchorSurvivesEverySidebarLayout() {
        let layouts: [(window: CGRect, openLocationX: CGFloat, panes: [CGRect])] = [
            (window, 1_696, []),
            (CGRect(x: 72, y: 72, width: 1_520, height: 1_049), 1_340, []),
            (CGRect(x: 72, y: 240, width: 1_520, height: 881), 1_340, []),
            (CGRect(x: 72, y: 240, width: 1_100, height: 700), 980, []),
        ]

        for layout in layouts {
            let anchor = ContentHeaderAnchorResolver.resolve(
                controls: [
                    ContentHeaderControl(
                        frame: CGRect(
                            x: layout.openLocationX,
                            y: layout.window.maxY - 37,
                            width: 91,
                            height: 28
                        ),
                        labels: ["打开位置"]
                    ),
                ],
                paneFrames: layout.panes,
                windowFrame: layout.window
            )
            let indicator = OverlayLayout.indicatorFrame(
                in: layout.window,
                contentTrailingEdge: anchor.trailingEdge
            )

            XCTAssertEqual(anchor.source, .openLocation)
            XCTAssertEqual(
                layout.openLocationX - indicator.maxX,
                OverlayLayout.indicatorGap
            )
        }
    }

    func testIgnoresLeftAndFullWidthPanes() {
        let anchor = ContentHeaderAnchorResolver.resolve(
            controls: [],
            paneFrames: [
                CGRect(x: 72, y: 72, width: 327, height: 1_049),
                CGRect(x: 399, y: 72, width: 1_521, height: 1_049),
            ],
            windowFrame: window
        )

        XCTAssertNil(anchor.trailingEdge)
        XCTAssertEqual(anchor.source, .fallback)
    }

    private func control(
        x: CGFloat,
        y: CGFloat = 1_084,
        width: CGFloat,
        labels: [String]
    ) -> ContentHeaderControl {
        ContentHeaderControl(
            frame: CGRect(x: x, y: y, width: width, height: 28),
            labels: labels
        )
    }
}
