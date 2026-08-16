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

        XCTAssertEqual(frame.width, 476)
        XCTAssertEqual(frame.minX, indicator.minX)
        XCTAssertEqual(frame.maxY, indicator.minY - 8)
    }

    func testReferenceGeometryOrdersHeaderTiboTokenBandAndScrollableRows() {
        let bounds = CGRect(x: 0, y: 0, width: 476, height: 804)
        let header = QuotaDetailLayout.headerFrames(
            in: bounds,
            titleWidth: 180,
            versionBadgeWidth: 48
        )
        let information = QuotaDetailLayout.informationFrames(
            in: bounds,
            tokenUsageVisible: true
        )

        XCTAssertEqual(QuotaDetailLayout.maximumHeight, 804)
        XCTAssertEqual(header.title.height, 28)
        XCTAssertGreaterThan(header.title.minY, information.topDivider.maxY)
        XCTAssertGreaterThan(header.remaining.minY, information.topDivider.maxY)
        XCTAssertLessThan(information.tokenBand.maxY, information.topDivider.minY)
        XCTAssertLessThan(information.rowArea.maxY, information.tokenBand.minY)
        XCTAssertGreaterThan(information.rowArea.minY, information.footer.maxY)
        XCTAssertEqual(information.tokenBand.width / 7, 60, accuracy: 0.5)
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

    func testNarrowsReferenceCardOnlyWhenVisibleFrameCannotFitIt() {
        let visibleFrame = CGRect(x: 100, y: 100, width: 400, height: 800)
        let frame = QuotaDetailLayout.frame(
            indicatorFrame: CGRect(x: 460, y: 700, width: 30, height: 30),
            rowCount: 6,
            visibleFrame: visibleFrame,
            tokenUsageVisible: true
        )

        XCTAssertEqual(frame.width, 384)
        XCTAssertEqual(frame.minX, 108)
        XCTAssertEqual(frame.maxX, 492)
    }

    func testCapsManyRowsForScrollableContent() {
        XCTAssertEqual(QuotaDetailLayout.contentHeight(rowCount: 100), 804)
        let frame = QuotaDetailLayout.frame(
            indicatorFrame: CGRect(x: 205, y: 390, width: 148, height: 46),
            rowCount: 100,
            visibleFrame: CGRect(x: 0, y: 0, width: 1_920, height: 420)
        )

        XCTAssertEqual(frame.height, 404)
        XCTAssertEqual(frame.minY, 8)
    }

    func testAccountsForWrappedDetailRows() {
        XCTAssertEqual(QuotaDetailLayout.contentHeight(rowContentHeight: 210), 504)
        let frame = QuotaDetailLayout.frame(
            indicatorFrame: CGRect(x: 100, y: 600, width: 148, height: 46),
            rowContentHeight: 210,
            visibleFrame: CGRect(x: 0, y: 0, width: 900, height: 700)
        )

        XCTAssertEqual(frame.height, 504)
    }

    func testInformationBandSeparatesProgressTiboTokenBandAndRows() {
        let bounds = CGRect(x: 0, y: 0, width: 476, height: 804)
        let frames = QuotaDetailLayout.informationFrames(
            in: bounds,
            tokenUsageVisible: true
        )

        XCTAssertEqual(frames.topDivider.minY, 600)
        XCTAssertEqual(
            frames.tokenBand,
            CGRect(x: 28, y: 338, width: 420, height: 250)
        )
        XCTAssertEqual(frames.footer, CGRect(x: 0, y: 0, width: 476, height: 66))
        XCTAssertEqual(frames.footerDivider.minY, 66)
        XCTAssertLessThan(frames.rowArea.maxY, frames.tokenBand.minY)
        XCTAssertGreaterThan(frames.rowArea.minY, frames.footer.maxY)
        XCTAssertTrue(bounds.contains(frames.tokenBand))
        XCTAssertTrue(bounds.contains(frames.rowArea))
    }

    func testTokenBandAddsFixedHeightWithoutChangingCardWidth() {
        XCTAssertEqual(
            QuotaDetailLayout.contentHeight(
                rowContentHeight: 240,
                tokenUsageVisible: true
            ),
            804
        )
        XCTAssertEqual(
            QuotaDetailLayout.contentHeight(
                rowContentHeight: 240,
                tokenUsageVisible: false
            ),
            534
        )
    }

    func testHeaderPlacesCompactVersionBadgeAfterAndAboveTitle() {
        let frames = QuotaDetailLayout.headerFrames(
            in: CGRect(x: 0, y: 0, width: 476, height: 300),
            titleWidth: 104,
            versionBadgeWidth: 48
        )

        XCTAssertEqual(
            frames.title,
            CGRect(x: 86, y: 246, width: 104, height: 28)
        )
        XCTAssertEqual(
            frames.versionBadge,
            CGRect(x: 198, y: 246, width: 48, height: 28)
        )
        XCTAssertEqual(frames.versionBadge.midY, frames.title.midY)
        XCTAssertLessThan(frames.remaining.maxY, frames.versionBadge.minY)
    }

    func testHeaderTruncatesLongTitleBeforeVersionAndRemaining() {
        let frames = QuotaDetailLayout.headerFrames(
            in: CGRect(x: 0, y: 0, width: 476, height: 300),
            titleWidth: 220,
            versionBadgeWidth: 52
        )

        XCTAssertEqual(frames.title.width, 220)
        XCTAssertEqual(frames.versionBadge.maxX, 366)
        XCTAssertEqual(frames.remaining.minX, 28)
    }

    func testLocalizedHeadersNeverOverlapBadgeOrPercentage() {
        for titleWidth in [82.0, 104.0, 132.0] {
            let frames = QuotaDetailLayout.headerFrames(
                in: CGRect(x: 0, y: 0, width: 476, height: 300),
                titleWidth: titleWidth,
                versionBadgeWidth: 42
            )

            XCTAssertLessThanOrEqual(frames.title.maxX, frames.versionBadge.minX)
            XCTAssertLessThanOrEqual(frames.versionBadge.maxX, 468)
            XCTAssertLessThan(frames.remaining.maxY, frames.title.minY)
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
