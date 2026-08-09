import SidebarCore
import XCTest

final class QuotaColorScaleTests: XCTestCase {
    func testHitsRequestedGreenOrangeAndRedAnchors() {
        XCTAssertEqual(
            QuotaColorScale.components(remainingPercent: 100).hue,
            0.36,
            accuracy: 0.000_1
        )
        XCTAssertEqual(
            QuotaColorScale.components(remainingPercent: 40).hue,
            0.078,
            accuracy: 0.000_1
        )
        XCTAssertEqual(
            QuotaColorScale.components(remainingPercent: 20).hue,
            0,
            accuracy: 0.000_1
        )
    }

    func testHueChangesContinuouslyAcrossTheWholeTransition() {
        let hues = [100, 80, 60, 40, 30, 20].map {
            QuotaColorScale.components(remainingPercent: $0).hue
        }

        for pair in zip(hues, hues.dropFirst()) {
            XCTAssertGreaterThan(pair.0, pair.1)
        }
        XCTAssertNotEqual(
            QuotaColorScale.components(remainingPercent: 99),
            QuotaColorScale.components(remainingPercent: 100)
        )
        XCTAssertNotEqual(
            QuotaColorScale.components(remainingPercent: 39),
            QuotaColorScale.components(remainingPercent: 40)
        )
        XCTAssertNotEqual(
            QuotaColorScale.components(remainingPercent: 19),
            QuotaColorScale.components(remainingPercent: 20)
        )
    }

    func testClampsValuesOutsidePercentageRange() {
        XCTAssertEqual(
            QuotaColorScale.components(remainingPercent: 120),
            QuotaColorScale.components(remainingPercent: 100)
        )
        XCTAssertEqual(
            QuotaColorScale.components(remainingPercent: -5),
            QuotaColorScale.components(remainingPercent: 0)
        )
    }
}
