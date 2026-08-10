import XCTest
@testable import SidebarCore

final class QuotaCountdownSegmentsTests: XCTestCase {
    func testSegmentsSimplifiedChineseCountdownWithoutChangingText() {
        let value = "8月16日 17:37（5d21h）"

        let segments = QuotaCountdownSegmenter.segments(in: value)

        XCTAssertEqual(
            segments,
            [
                .init(text: "8月16日 17:37", role: .plain),
                .init(text: "（", role: .punctuation),
                .init(text: "5", role: .digits),
                .init(text: "d", role: .unit),
                .init(text: "21", role: .digits),
                .init(text: "h", role: .unit),
                .init(text: "）", role: .punctuation)
            ]
        )
        XCTAssertEqual(segments.map(\.text).joined(), value)
    }

    func testSegmentsEnglishCountdownAndPreservesLeadingSpace() {
        let value = "Aug 16, 17:37 (5d21h)"

        XCTAssertEqual(
            QuotaCountdownSegmenter.segments(in: value),
            [
                .init(text: "Aug 16, 17:37 ", role: .plain),
                .init(text: "(", role: .punctuation),
                .init(text: "5", role: .digits),
                .init(text: "d", role: .unit),
                .init(text: "21", role: .digits),
                .init(text: "h", role: .unit),
                .init(text: ")", role: .punctuation)
            ]
        )
    }

    func testSegmentsPastIntervalAndStatusSuffix() {
        let value = "7月26日 01:19（<1m前） · 已过期"

        XCTAssertEqual(
            QuotaCountdownSegmenter.segments(in: value),
            [
                .init(text: "7月26日 01:19", role: .plain),
                .init(text: "（<", role: .punctuation),
                .init(text: "1", role: .digits),
                .init(text: "m", role: .unit),
                .init(text: "前", role: .suffix),
                .init(text: "）", role: .punctuation),
                .init(text: " · 已过期", role: .plain)
            ]
        )
    }

    func testSegmentsEnglishPastSuffixAsMutedText() {
        let value = "Jul 26, 01:19 (2d6h ago)"

        XCTAssertEqual(
            QuotaCountdownSegmenter.segments(in: value),
            [
                .init(text: "Jul 26, 01:19 ", role: .plain),
                .init(text: "(", role: .punctuation),
                .init(text: "2", role: .digits),
                .init(text: "d", role: .unit),
                .init(text: "6", role: .digits),
                .init(text: "h", role: .unit),
                .init(text: " ago", role: .suffix),
                .init(text: ")", role: .punctuation)
            ]
        )
    }

    func testLeavesValuesWithoutCompactDurationUntouched() {
        for value in ["Plus", "7 天", "暂无数据", "8月16日 17:37"] {
            XCTAssertEqual(
                QuotaCountdownSegmenter.segments(in: value),
                [.init(text: value, role: .plain)]
            )
        }
    }

    func testRejectsParenthesizedTextThatIsNotACompactDuration() {
        let value = "备注（即将到期）"

        XCTAssertEqual(
            QuotaCountdownSegmenter.segments(in: value),
            [.init(text: value, role: .plain)]
        )
    }
}
