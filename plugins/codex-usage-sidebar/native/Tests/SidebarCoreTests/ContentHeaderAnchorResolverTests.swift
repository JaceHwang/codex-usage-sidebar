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

    func testRetainsCachedOpenLocationAcrossTransientFallback() {
        let cached = ContentHeaderAnchor(
            trailingEdge: 1_696,
            source: .openLocation
        )

        let stabilized = ContentHeaderAnchorResolver.stabilized(
            scanned: ContentHeaderAnchor(
                trailingEdge: nil,
                source: .fallback
            ),
            cached: cached
        )

        XCTAssertEqual(stabilized, cached)
    }

    func testRetainsCachedOpenLocationAcrossTransientBoundaryResult() {
        let cached = ContentHeaderAnchor(
            trailingEdge: 1_696,
            source: .openLocation
        )

        let stabilized = ContentHeaderAnchorResolver.stabilized(
            scanned: ContentHeaderAnchor(
                trailingEdge: 1_604,
                source: .rightPaneBoundary
            ),
            cached: cached
        )

        XCTAssertEqual(stabilized, cached)
    }

    func testFreshOpenLocationReplacesCachedOpenLocation() {
        let scanned = ContentHeaderAnchor(
            trailingEdge: 1_720,
            source: .openLocation
        )

        let stabilized = ContentHeaderAnchorResolver.stabilized(
            scanned: scanned,
            cached: ContentHeaderAnchor(
                trailingEdge: 1_696,
                source: .openLocation
            )
        )

        XCTAssertEqual(stabilized, scanned)
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

    func testOpenLocationLeftOfWindowMidpointUsesVisibleFreeSlot() {
        let wideWindow = CGRect(x: 70, y: 0, width: 1_850, height: 1_049)
        let anchor = ContentHeaderAnchorResolver.resolve(
            controls: [
                control(x: 768, y: 1_012, width: 132, labels: ["打开位置"]),
                control(x: 910, y: 1_012, width: 28, labels: ["环境信息"]),
            ],
            paneFrames: [CGRect(x: 955, y: 0, width: 965, height: 1_049)],
            windowFrame: wideWindow
        )

        XCTAssertEqual(anchor, ContentHeaderAnchor(trailingEdge: 768, source: .openLocation))
        XCTAssertEqual(
            OverlayLayout.indicatorFrame(in: wideWindow, contentTrailingEdge: anchor.trailingEdge),
            CGRect(x: 596, y: 1_003, width: 164, height: 46)
        )
    }

    func testOpenLocationLeftOfWindowMidpointFallsBackAtStaticTitleBarrier() {
        let wideWindow = CGRect(x: 70, y: 0, width: 1_850, height: 1_049)
        let anchor = ContentHeaderAnchorResolver.resolve(
            controls: [
                ContentHeaderControl(
                    frame: CGRect(x: 650, y: 1_012, width: 160, height: 28),
                    labels: ["Thread title"],
                    isAnchorCandidate: false
                ),
                control(x: 820, y: 1_012, width: 70, labels: ["Other action"]),
                control(x: 905, y: 1_012, width: 132, labels: ["打开位置"]),
            ],
            paneFrames: [CGRect(x: 955, y: 0, width: 965, height: 1_049)],
            windowFrame: wideWindow
        )

        XCTAssertEqual(
            anchor,
            ContentHeaderAnchor(
                trailingEdge: wideWindow.maxX - 168,
                source: .fallback
            )
        )
    }

    func testProgressiveScanFindsStaticTitleBarrierLeftOfFixedScanBound() {
        let wideWindow = CGRect(x: 70, y: 0, width: 1_850, height: 1_049)
        let controls = [
            ContentHeaderControl(
                frame: CGRect(x: 580, y: 1_012, width: 160, height: 28),
                labels: ["Thread title"],
                isAnchorCandidate: false
            ),
            control(x: 905, y: 1_012, width: 132, labels: ["打开位置"]),
        ]
        let result = progressiveAnchor(
            controls: controls,
            paneFrames: [CGRect(x: 955, y: 0, width: 965, height: 1_049)],
            windowFrame: wideWindow
        )

        XCTAssertEqual(
            result.anchor,
            ContentHeaderAnchor(
                trailingEdge: wideWindow.maxX - 168,
                source: .fallback
            )
        )
        XCTAssertEqual(result.scanPasses, 2)
    }

    func testProgressiveScanIncludesStaticTitleInsideIndicatorGapPadding() {
        let wideWindow = CGRect(x: 70, y: 0, width: 1_850, height: 1_049)
        let result = progressiveAnchor(
            controls: [
                ContentHeaderControl(
                    frame: CGRect(x: 572, y: 1_012, width: 160, height: 28),
                    labels: ["Thread title"],
                    isAnchorCandidate: false
                ),
                control(x: 905, y: 1_012, width: 132, labels: ["打开位置"]),
            ],
            paneFrames: [],
            windowFrame: wideWindow
        )

        XCTAssertEqual(
            result.anchor,
            ContentHeaderAnchor(
                trailingEdge: wideWindow.maxX - 168,
                source: .fallback
            )
        )
        XCTAssertEqual(result.minimumX, 725)
    }

    func testProgressiveScanKeepsWideOpenLocationWhenItsIndicatorIsFree() {
        let wideWindow = CGRect(x: 70, y: 0, width: 1_850, height: 1_049)
        let result = progressiveAnchor(
            controls: [
                control(x: 905, y: 1_012, width: 132, labels: ["打开位置"]),
            ],
            paneFrames: [CGRect(x: 955, y: 0, width: 965, height: 1_049)],
            windowFrame: wideWindow
        )

        XCTAssertEqual(
            result.anchor,
            ContentHeaderAnchor(trailingEdge: 905, source: .openLocation)
        )
        XCTAssertEqual(result.scanPasses, 2)
    }

    func testProgressiveScanExpandsAgainAfterButtonCollisionSlidesLeft() {
        let wideWindow = CGRect(x: 70, y: 0, width: 1_850, height: 1_049)
        let result = progressiveAnchor(
            controls: [
                ContentHeaderControl(
                    frame: CGRect(x: 600, y: 1_012, width: 140, height: 28),
                    labels: ["Thread title"],
                    isAnchorCandidate: false
                ),
                control(x: 820, y: 1_012, width: 70, labels: ["Other action"]),
                control(x: 905, y: 1_012, width: 132, labels: ["打开位置"]),
            ],
            paneFrames: [CGRect(x: 955, y: 0, width: 965, height: 1_049)],
            windowFrame: wideWindow
        )

        XCTAssertEqual(
            result.anchor,
            ContentHeaderAnchor(
                trailingEdge: wideWindow.maxX - 168,
                source: .fallback
            )
        )
        XCTAssertEqual(result.scanPasses, 2)
        XCTAssertEqual(result.minimumX, 640)
    }

    func testProgressiveScanStopsAfterFallbackOrCoveredIndicatorRange() {
        let wideWindow = CGRect(x: 70, y: 0, width: 1_850, height: 1_049)
        let free = progressiveAnchor(
            controls: [control(x: 905, y: 1_012, width: 132, labels: ["打开位置"])],
            paneFrames: [],
            windowFrame: wideWindow
        )
        let blocked = progressiveAnchor(
            controls: [
                ContentHeaderControl(
                    frame: CGRect(x: 580, y: 1_012, width: 160, height: 28),
                    labels: ["Thread title"],
                    isAnchorCandidate: false
                ),
                control(x: 905, y: 1_012, width: 132, labels: ["打开位置"]),
            ],
            paneFrames: [],
            windowFrame: wideWindow
        )

        XCTAssertEqual(free.scanPasses, 2)
        XCTAssertEqual(blocked.scanPasses, 2)
        XCTAssertEqual(blocked.anchor.source, .fallback)
    }

    func testProgressiveScanFallsBackWhenPassCapLeavesStaticTitleHidden() {
        let wideWindow = CGRect(x: 70, y: 0, width: 1_850, height: 1_049)
        let result = progressiveAnchor(
            controls: [
                ContentHeaderControl(
                    frame: CGRect(x: 200, y: 1_012, width: 160, height: 28),
                    labels: ["Thread title"],
                    isAnchorCandidate: false
                ),
                control(x: 460, y: 1_012, width: 30, labels: ["Action"]),
                control(x: 580, y: 1_012, width: 30, labels: ["Action"]),
                control(x: 700, y: 1_012, width: 30, labels: ["Action"]),
                control(x: 820, y: 1_012, width: 30, labels: ["Action"]),
                control(x: 905, y: 1_012, width: 132, labels: ["打开位置"]),
            ],
            paneFrames: [],
            windowFrame: wideWindow
        )

        XCTAssertEqual(result.scanPasses, 4)
        XCTAssertEqual(
            result.anchor,
            ContentHeaderAnchor(
                trailingEdge: wideWindow.maxX - 168,
                source: .fallback
            )
        )
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

    func testRecognizesWideRightPaneBoundaryWithoutTreatingFullContentAsPane() {
        let wideWindow = CGRect(x: 70, y: 0, width: 1_850, height: 1_049)
        let anchor = ContentHeaderAnchorResolver.resolve(
            controls: [],
            paneFrames: [CGRect(x: 955, y: 0, width: 965, height: 1_049)],
            windowFrame: wideWindow
        )

        XCTAssertEqual(anchor, ContentHeaderAnchor(trailingEdge: 955, source: .rightPaneBoundary))
    }

    func testOpenLocationRemainsAnchorInsideRightPane() {
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

        XCTAssertEqual(anchor.trailingEdge, 1_696)
        XCTAssertEqual(anchor.source, .openLocation)

        let indicator = OverlayLayout.indicatorFrame(
            in: window,
            contentTrailingEdge: anchor.trailingEdge
        )
        XCTAssertEqual(
            1_696 - indicator.maxX,
            OverlayLayout.indicatorGap
        )
    }

    func testMultipleOpenLocationControlsUseNearestNonOverlappingSlot() {
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

    func testSlidesLeftIntoNearestFreeSlotWhenPreferredAnchorWouldOverlapAControl() {
        let anchor = ContentHeaderAnchorResolver.resolve(
            controls: [
                control(x: 900, width: 120, labels: []),
                control(x: 1_040, width: 80, labels: ["Renamed action"]),
            ],
            paneFrames: [],
            windowFrame: window
        )

        XCTAssertEqual(anchor.trailingEdge, 900)
        XCTAssertEqual(anchor.source, .labeledControl)

        let indicator = OverlayLayout.indicatorFrame(
            in: window,
            contentTrailingEdge: anchor.trailingEdge
        )
        XCTAssertFalse(indicator.intersects(CGRect(
            x: 900,
            y: 1_084,
            width: 120,
            height: 28
        )))
    }

    func testIgnoresStaticTextNestedInsideSelectedOpenLocationButton() {
        let openLocationFrame = CGRect(
            x: 1_696,
            y: 1_084,
            width: 104,
            height: 36
        )
        let anchor = ContentHeaderAnchorResolver.resolve(
            controls: [
                ContentHeaderControl(
                    frame: openLocationFrame,
                    labels: ["打开位置"]
                ),
                ContentHeaderControl(
                    frame: CGRect(x: 1_720, y: 1_091, width: 68, height: 22),
                    labels: ["打开位置"],
                    isAnchorCandidate: false
                ),
            ],
            paneFrames: [],
            windowFrame: window
        )

        XCTAssertEqual(anchor.trailingEdge, openLocationFrame.minX)
        XCTAssertEqual(anchor.source, .openLocation)
    }

    func testIgnoresDegenerateContentClippedToTopWindowEdge() {
        let openLocationFrame = CGRect(
            x: 1_696,
            y: 1_012,
            width: 91,
            height: 28
        )
        let anchor = ContentHeaderAnchorResolver.resolve(
            controls: [
                ContentHeaderControl(
                    frame: openLocationFrame,
                    labels: ["打开位置"]
                ),
                ContentHeaderControl(
                    frame: CGRect(x: 639, y: 1_048, width: 1_261, height: 1),
                    labels: [],
                    isAnchorCandidate: false
                ),
            ],
            paneFrames: [],
            windowFrame: CGRect(x: 72, y: 0, width: 1_848, height: 1_049)
        )

        XCTAssertEqual(anchor.trailingEdge, openLocationFrame.minX)
        XCTAssertEqual(anchor.source, .openLocation)
    }

    func testReevaluatesCollisionWhenObstacleAppearsAtSameAnchor() {
        let openLocation = control(
            x: 1_040,
            width: 80,
            labels: ["打开位置"]
        )
        let initial = ContentHeaderAnchorResolver.resolve(
            controls: [openLocation],
            paneFrames: [],
            windowFrame: window
        )
        let afterObstacleAppears = ContentHeaderAnchorResolver.resolve(
            controls: [
                control(x: 900, width: 120, labels: []),
                openLocation,
            ],
            paneFrames: [],
            windowFrame: window
        )

        XCTAssertEqual(initial.trailingEdge, 1_040)
        XCTAssertEqual(afterObstacleAppears.trailingEdge, 900)
        XCTAssertEqual(afterObstacleAppears.source, .openLocation)
    }

    func testUsesImmediateTrailingFallbackWhenNoFreeSlotRemains() {
        let anchor = ContentHeaderAnchorResolver.resolve(
            controls: [
                control(x: 72, width: 828, labels: []),
                control(x: 900, width: 120, labels: []),
                control(x: 1_040, width: 80, labels: ["Renamed action"]),
            ],
            paneFrames: [],
            windowFrame: window
        )

        XCTAssertEqual(anchor.trailingEdge, window.maxX - 168)
        XCTAssertEqual(anchor.source, .fallback)
        XCTAssertEqual(
            OverlayLayout.indicatorFrame(
                in: window,
                contentTrailingEdge: anchor.trailingEdge
            ),
            OverlayLayout.indicatorFrame(
                in: window,
                contentTrailingEdge: nil
            )
        )
    }

    func testDoesNotRelocateBeforeAStaticTitleBarrier() {
        let anchor = ContentHeaderAnchorResolver.resolve(
            controls: [
                ContentHeaderControl(
                    frame: CGRect(x: 700, y: 1_084, width: 180, height: 28),
                    labels: ["Thread title"],
                    isAnchorCandidate: false
                ),
                control(x: 900, width: 120, labels: []),
                control(x: 1_040, width: 80, labels: ["Renamed action"]),
            ],
            paneFrames: [],
            windowFrame: window
        )

        XCTAssertEqual(anchor.trailingEdge, window.maxX - 168)
        XCTAssertEqual(anchor.source, .fallback)
    }

    func testIntentionalTrailingFallbackReplacesCachedOpenLocation() {
        let scanned = ContentHeaderAnchor(
            trailingEdge: window.maxX - 168,
            source: .fallback
        )

        let stabilized = ContentHeaderAnchorResolver.stabilized(
            scanned: scanned,
            cached: ContentHeaderAnchor(
                trailingEdge: 1_696,
                source: .openLocation
            )
        )

        XCTAssertEqual(stabilized, scanned)
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

    func testScanRegionIncludesPaneThatCanOverlapIndicatorLeftOfWindowMidpoint() {
        XCTAssertTrue(
            ContentHeaderAnchorResolver.shouldScanDescendants(
                of: CGRect(x: 310, y: 0, width: 670, height: 1_049),
                windowFrame: CGRect(x: 70, y: 0, width: 1_850, height: 1_049)
            )
        )
        XCTAssertFalse(
            ContentHeaderAnchorResolver.shouldScanDescendants(
                of: CGRect(x: 70, y: 0, width: 620, height: 1_049),
                windowFrame: CGRect(x: 70, y: 0, width: 1_850, height: 1_049)
            )
        )
        XCTAssertFalse(
            ContentHeaderAnchorResolver.shouldScanDescendants(
                of: CGRect(x: 310, y: 0, width: 670, height: 900),
                windowFrame: CGRect(x: 70, y: 0, width: 1_850, height: 1_049)
            )
        )
        XCTAssertFalse(
            ContentHeaderAnchorResolver.shouldScanDescendants(
                of: CGRect(x: 639, y: 1_048, width: 1_261, height: 1),
                windowFrame: CGRect(x: 72, y: 0, width: 1_848, height: 1_049)
            )
        )
    }

    func testToolbarEligibilityRejectsClippedContentBeforeLabelRead() {
        let fullscreenWindow = CGRect(x: 72, y: 0, width: 1_848, height: 1_049)

        XCTAssertTrue(
            ContentHeaderAnchorResolver.isEligibleToolbarItem(
                frame: CGRect(x: 1_696, y: 1_012, width: 91, height: 28),
                windowFrame: fullscreenWindow
            )
        )
        XCTAssertFalse(
            ContentHeaderAnchorResolver.isEligibleToolbarItem(
                frame: CGRect(x: 639, y: 1_048, width: 1_261, height: 1),
                windowFrame: fullscreenWindow
            )
        )
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

    private func progressiveAnchor(
        controls: [ContentHeaderControl],
        paneFrames: [CGRect],
        windowFrame: CGRect
    ) -> (anchor: ContentHeaderAnchor, scanPasses: Int, minimumX: CGFloat) {
        var minimumX = ContentHeaderAnchorResolver.initialScanMinimumX(in: windowFrame)
        var scanPasses = 0
        var anchor = ContentHeaderAnchor(trailingEdge: nil, source: .fallback)

        while scanPasses < 4 {
            let scannedControls = controls.filter {
                ContentHeaderAnchorResolver.shouldScanDescendants(
                    of: $0.frame,
                    windowFrame: windowFrame,
                    minimumX: minimumX
                )
            }
            anchor = ContentHeaderAnchorResolver.resolve(
                controls: scannedControls,
                paneFrames: paneFrames,
                windowFrame: windowFrame
            )
            scanPasses += 1
            guard
                scanPasses < 4,
                let expandedMinimumX = ContentHeaderAnchorResolver.expandedScanMinimumX(
                after: anchor,
                currentMinimumX: minimumX,
                windowFrame: windowFrame
                )
            else {
                break
            }
            minimumX = expandedMinimumX
        }
        if scanPasses == 4 {
            anchor = ContentHeaderAnchorResolver.fallbackIfScanIsIncomplete(
                anchor: anchor,
                currentMinimumX: minimumX,
                windowFrame: windowFrame
            )
        }
        return (anchor, scanPasses, minimumX)
    }
}
