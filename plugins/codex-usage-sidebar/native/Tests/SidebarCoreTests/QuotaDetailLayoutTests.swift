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
            304
        )
        let frame = QuotaDetailLayout.frame(
            indicatorFrame: CGRect(x: 100, y: 600, width: 148, height: 46),
            rowContentHeight: 210,
            visibleFrame: CGRect(x: 0, y: 0, width: 900, height: 700)
        )

        XCTAssertEqual(frame.height, 304)
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
