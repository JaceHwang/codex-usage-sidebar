import CoreGraphics
import XCTest
@testable import SidebarCore

final class QuotaDetailLayoutTests: XCTestCase {
    private let visibleFrame = CGRect(x: 0, y: 0, width: 1_920, height: 1_080)

    func testCardOpensBelowHeaderIndicatorAndAlignsLeadingEdges() {
        let indicator = CGRect(x: 886, y: 1_026, width: 148, height: 46)
        let frame = QuotaDetailLayout.frame(
            indicatorFrame: indicator,
            rowCount: 6,
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(frame.width, 300)
        XCTAssertEqual(frame.minX, indicator.minX)
        XCTAssertEqual(frame.maxY, indicator.minY - 8)
    }

    func testClampsCardToVisibleHorizontalMargins() {
        let nearRight = CGRect(x: 1_850, y: 900, width: 60, height: 46)
        let nearLeft = CGRect(x: -20, y: 900, width: 60, height: 46)
        let rightFrame = QuotaDetailLayout.frame(
            indicatorFrame: nearRight,
            rowCount: 1,
            visibleFrame: visibleFrame
        )
        let leftFrame = QuotaDetailLayout.frame(
            indicatorFrame: nearLeft,
            rowCount: 1,
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(rightFrame.maxX, visibleFrame.maxX - 8)
        XCTAssertEqual(leftFrame.minX, visibleFrame.minX + 8)
    }

    func testCapsManyRowsForScrollableContent() {
        XCTAssertEqual(QuotaDetailLayout.contentHeight(rowCount: 100), 480)
        let frame = QuotaDetailLayout.frame(
            indicatorFrame: CGRect(x: 205, y: 390, width: 148, height: 46),
            rowCount: 100,
            visibleFrame: CGRect(x: 0, y: 0, width: 1_920, height: 420)
        )

        XCTAssertEqual(frame.height, 404)
        XCTAssertEqual(frame.minY, 8)
    }

    func testAccountsForWrappedDetailRows() {
        XCTAssertEqual(
            QuotaDetailLayout.contentHeight(rowContentHeight: 210),
            346
        )
        let frame = QuotaDetailLayout.frame(
            indicatorFrame: CGRect(x: 100, y: 600, width: 148, height: 46),
            rowContentHeight: 210,
            visibleFrame: CGRect(x: 0, y: 0, width: 900, height: 700)
        )

        XCTAssertEqual(frame.height, 346)
    }

    func testInformationBandSeparatesProgressTiboTokenBandAndRows() {
        let bounds = CGRect(x: 0, y: 0, width: 300, height: 440)
        let frames = QuotaDetailLayout.informationFrames(
            in: bounds,
            tokenUsageVisible: true
        )

        XCTAssertEqual(
            frames.control,
            CGRect(x: 12, y: 334, width: 276, height: 32)
        )
        XCTAssertEqual(frames.topDivider.minY, 374)
        XCTAssertEqual(frames.bottomDivider.minY, 326)
        XCTAssertEqual(
            frames.tokenBand,
            CGRect(x: 12, y: 206, width: 276, height: 112)
        )
        XCTAssertLessThan(frames.control.maxY, frames.topDivider.minY)
        XCTAssertGreaterThan(frames.control.minY, frames.bottomDivider.maxY)
        XCTAssertLessThanOrEqual(frames.tokenBand.maxY, frames.bottomDivider.minY)
        XCTAssertLessThan(frames.rowArea.maxY, frames.tokenBand.minY)
        XCTAssertEqual(frames.rowArea.maxY, 198)
        XCTAssertTrue(bounds.contains(frames.tokenBand))
        XCTAssertTrue(bounds.contains(frames.rowArea))
    }

    func testTokenBandAddsFixedHeightWithoutChangingCardWidth() {
        XCTAssertEqual(
            QuotaDetailLayout.contentHeight(
                rowContentHeight: 144,
                tokenUsageVisible: true
            ),
            402
        )
        XCTAssertEqual(
            QuotaDetailLayout.contentHeight(
                rowContentHeight: 144,
                tokenUsageVisible: false
            ),
            280
        )
    }

    func testHeaderPlacesCompactVersionBadgeAfterAndAboveTitle() {
        let frames = QuotaDetailLayout.headerFrames(
            in: CGRect(x: 0, y: 0, width: 300, height: 240),
            titleWidth: 104,
            versionBadgeWidth: 48
        )

        XCTAssertEqual(
            frames.title,
            CGRect(x: 12, y: 205, width: 104, height: 20)
        )
        XCTAssertEqual(
            frames.versionBadge,
            CGRect(x: 122, y: 210, width: 48, height: 14)
        )
        XCTAssertEqual(frames.versionBadge.midY, frames.title.midY + 2)
        XCTAssertGreaterThanOrEqual(
            frames.remaining.minX - frames.versionBadge.maxX,
            8
        )
    }

    func testHeaderTruncatesLongTitleBeforeVersionAndRemaining() {
        let frames = QuotaDetailLayout.headerFrames(
            in: CGRect(x: 0, y: 0, width: 300, height: 240),
            titleWidth: 220,
            versionBadgeWidth: 52
        )

        XCTAssertEqual(frames.title.width, 155)
        XCTAssertEqual(frames.versionBadge.maxX, 225)
        XCTAssertEqual(frames.remaining.minX, 233)
    }

    func testLocalizedHeadersNeverOverlapBadgeOrPercentage() {
        for titleWidth in [82.0, 104.0, 132.0] {
            let frames = QuotaDetailLayout.headerFrames(
                in: CGRect(x: 0, y: 0, width: 300, height: 240),
                titleWidth: titleWidth,
                versionBadgeWidth: 42
            )

            XCTAssertLessThanOrEqual(frames.title.maxX, frames.versionBadge.minX)
            XCTAssertLessThanOrEqual(
                frames.versionBadge.maxX + 8,
                frames.remaining.minX
            )
        }
    }

    func testHeaderTitleMeasurementKeepsAppKitFittingAllowance() {
        XCTAssertEqual(
            QuotaDetailLayout.titleWidth(
                intrinsicWidth: 95.5,
                fittingWidth: 100
            ),
            100
        )
    }

    func testHoverBridgeCoversGapBelowIndicator() {
        let indicator = CGRect(x: 886, y: 1_026, width: 148, height: 46)
        let detail = CGRect(x: 886, y: 780, width: 220, height: 238)

        XCTAssertEqual(
            QuotaDetailLayout.hoverBridgeFrame(
                indicatorFrame: indicator,
                detailFrame: detail
            ),
            CGRect(x: 886, y: 1_018, width: 148, height: 8)
        )
    }
}
