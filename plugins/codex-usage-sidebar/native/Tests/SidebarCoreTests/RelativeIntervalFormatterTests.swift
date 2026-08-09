import Foundation
import XCTest
@testable import SidebarCore

final class RelativeIntervalFormatterTests: XCTestCase {
    private let formatter = RelativeIntervalFormatter()
    private let now = Date(timeIntervalSince1970: 1_000_000)

    func testFormatsFutureIntervalsAtUsefulPrecision() {
        XCTAssertEqual(format(after: 6 * 86_400), "6天0小时")
        XCTAssertEqual(
            format(after: 3 * 86_400 + 8 * 3_600 + 59 * 60),
            "3天8小时"
        )
        XCTAssertEqual(format(after: 8 * 3_600 + 15 * 60), "8小时15分钟")
        XCTAssertEqual(format(after: 42 * 60), "42分钟")
        XCTAssertEqual(format(after: 42), "不足1分钟")
    }

    func testFormatsPastIntervalsWithoutNegativeValues() {
        XCTAssertEqual(format(after: -6 * 86_400), "6天0小时前")
        XCTAssertEqual(
            format(after: -8 * 3_600 - 15 * 60),
            "8小时15分钟前"
        )
        XCTAssertEqual(format(after: -42 * 60), "42分钟前")
        XCTAssertEqual(format(after: -42), "不足1分钟前")
    }

    private func format(after interval: TimeInterval) -> String {
        formatter.string(from: now, to: now.addingTimeInterval(interval))
    }
}
