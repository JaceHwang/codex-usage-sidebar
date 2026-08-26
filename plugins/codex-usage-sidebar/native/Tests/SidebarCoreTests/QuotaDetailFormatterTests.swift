import Foundation
import XCTest
@testable import SidebarCore

final class QuotaDetailFormatterTests: XCTestCase {
    private let formatter = QuotaDetailFormatter()
    private let timeZone = TimeZone(identifier: "Asia/Shanghai")!
    private let now = Date(timeIntervalSince1970: 1_785_000_000)

    func testCarriesCodexAccountNameIntoFooterPresentation() {
        let content = formatter.content(
            snapshot: fullSnapshot,
            footerName: "Jace",
            now: now,
            language: .simplifiedChinese,
            timeZone: timeZone
        )

        XCTAssertEqual(content.footerName, "Jace")
    }

    func testFormatsBankCountAndEveryExpiry() {
        let content = formatter.content(
            snapshot: fullSnapshot,
            now: now,
            language: .simplifiedChinese,
            timeZone: timeZone
        )

        XCTAssertEqual(content.remainingPercent, 76)
        XCTAssertEqual(content.informationEntry.title, "Tibo 的 X 动态")
        XCTAssertEqual(
            content.informationEntry.accessibilityLabel,
            "在浏览器中打开 Tibo 的 X 主页"
        )
        XCTAssertEqual(
            content.informationEntry.destination.absoluteString,
            "https://x.com/thsottiaux"
        )
        XCTAssertTrue(
            content.rows.contains(.init(label: "Bank 可用重置", value: "2 次"))
        )
        XCTAssertTrue(
            content.rows.contains(
                .init(
                    label: "Bank 1到期时间",
                    value: "8月1日 04:19（6d2h）"
                )
            )
        )
        XCTAssertTrue(
            content.rows.contains(
                .init(
                    label: "Bank 2到期时间",
                    value: "8月13日 02:00（18d0h）"
                )
            )
        )
        XCTAssertTrue(
            content.rows.contains(
                .init(
                    label: "下次重置",
                    value: "7天6小时（2026/08/02 08:00）",
                    valueStyle: .resetCountdown
                )
            )
        )
        XCTAssertTrue(content.rows.contains(.init(label: "套餐", value: "Plus")))
        XCTAssertTrue(content.rows.contains(.init(label: "额度周期", value: "7 天")))
        XCTAssertTrue(content.rows.contains(.init(label: "Credits", value: "12.50")))
    }

    func testFormatsPrimaryAndSecondaryQuotaWindowsAndRows() {
        let content = formatter.content(
            snapshot: dualWindowSnapshot,
            now: now,
            language: .simplifiedChinese,
            timeZone: timeZone
        )

        XCTAssertEqual(content.quotaWindows.map(\.label), ["5 小时", "7 天"])
        XCTAssertEqual(content.quotaWindows.map(\.remainingPercent), [85, 98])
        XCTAssertEqual(
            content.rows.map(\.label),
            [
                "套餐", "额度周期", "下次重置",
                "额度周期（7天）", "下次重置（7天）",
                "Credits", "Bank 可用重置", "数据更新"
            ]
        )
        XCTAssertTrue(content.rows.contains(.init(label: "额度周期（7天）", value: "7 天")))
        XCTAssertTrue(content.rows.contains(
            .init(
                label: "下次重置（7天）",
                value: "37天6小时（2026/09/01 08:00）",
                valueStyle: .resetCountdown
            )
        ))
    }

    func testFormatsUnavailableAndZeroBankDistinctly() {
        let unavailable = formatter.content(
            snapshot: snapshot(bank: nil),
            now: now,
            language: .simplifiedChinese,
            timeZone: timeZone
        )
        let empty = formatter.content(
            snapshot: snapshot(bank: BankResetSummary(availableCount: 0, credits: [])),
            now: now,
            language: .simplifiedChinese,
            timeZone: timeZone
        )
        let countWithoutDetails = formatter.content(
            snapshot: snapshot(
                bank: BankResetSummary(availableCount: 2, credits: nil)
            ),
            now: now,
            language: .simplifiedChinese,
            timeZone: timeZone
        )

        XCTAssertTrue(
            unavailable.rows.contains(
                .init(label: "Bank 可用重置", value: "暂无数据")
            )
        )
        XCTAssertTrue(
            empty.rows.contains(.init(label: "Bank 可用重置", value: "0 次"))
        )
        XCTAssertTrue(bankRows(in: empty).isEmpty)
        XCTAssertTrue(
            countWithoutDetails.rows.contains(
                .init(label: "Bank 明细", value: "暂无数据")
            )
        )
    }

    func testSortsAllBankCreditsAndDisplaysStatusAndMissingExpiry() {
        let content = formatter.content(
            snapshot: snapshot(
                bank: BankResetSummary(
                    availableCount: 2,
                    credits: [
                        BankResetCredit(
                            status: "available",
                            grantedAt: nil,
                            expiresAt: nil,
                            title: "No expiry",
                            description: nil
                        ),
                        BankResetCredit(
                            status: "used",
                            grantedAt: nil,
                            expiresAt: Date(timeIntervalSince1970: 1_786_557_641),
                            title: "Used reset",
                            description: nil
                        ),
                        BankResetCredit(
                            status: "available",
                            grantedAt: nil,
                            expiresAt: Date(timeIntervalSince1970: 1_785_529_171),
                            title: "Available reset",
                            description: nil
                        ),
                        BankResetCredit(
                            status: "expired",
                            grantedAt: nil,
                            expiresAt: Date(timeIntervalSince1970: 1_784_999_940),
                            title: "Expired reset",
                            description: nil
                        )
                    ]
                )
            ),
            now: now,
            language: .simplifiedChinese,
            timeZone: timeZone
        )

        XCTAssertEqual(
            bankRows(in: content),
            [
                .init(
                    label: "Bank 1到期时间",
                    value: "7月26日 01:19（1m前） · 已过期"
                ),
                .init(
                    label: "Bank 2到期时间",
                    value: "8月1日 04:19（6d2h）"
                ),
                .init(
                    label: "Bank 3到期时间",
                    value: "8月13日 02:00（18d0h） · 已使用"
                ),
                .init(label: "Bank 4到期时间", value: "未提供到期时间")
            ]
        )
    }

    func testPreservesUsedAndExpiredStatusWhenBankExpiryIsMissing() {
        let content = formatter.content(
            snapshot: snapshot(
                bank: BankResetSummary(
                    availableCount: 0,
                    credits: [
                        BankResetCredit(
                            status: "used",
                            grantedAt: nil,
                            expiresAt: nil,
                            title: "Used reset",
                            description: nil
                        ),
                        BankResetCredit(
                            status: "expired",
                            grantedAt: nil,
                            expiresAt: nil,
                            title: "Expired reset",
                            description: nil
                        )
                    ]
                )
            ),
            now: now,
            language: .simplifiedChinese,
            timeZone: timeZone
        )

        XCTAssertEqual(
            bankRows(in: content).map(\.value),
            ["未提供到期时间 · 已使用", "未提供到期时间 · 已过期"]
        )
    }

    func testFormatsEnglishContentAndDates() {
        let content = formatter.content(
            snapshot: fullSnapshot,
            now: now,
            language: .english,
            timeZone: timeZone
        )

        XCTAssertEqual(content.title, "Codex quota")
        XCTAssertEqual(content.informationEntry.title, "Tibo on X")
        XCTAssertEqual(
            content.informationEntry.accessibilityLabel,
            "Open Tibo's X profile in the browser"
        )
        XCTAssertEqual(
            content.informationEntry.destination.absoluteString,
            "https://x.com/thsottiaux"
        )
        XCTAssertTrue(content.rows.contains(.init(label: "Plan", value: "Plus")))
        XCTAssertTrue(
            content.rows.contains(.init(label: "Quota window", value: "7 days"))
        )
        XCTAssertTrue(
            content.rows.contains(
                .init(
                    label: "Next reset",
                    value: "7d 6h (2026/08/02 08:00)",
                    valueStyle: .resetCountdown
                )
            )
        )
        XCTAssertTrue(
            content.rows.contains(
                .init(label: "Bank resets available", value: "2 resets")
            )
        )
        XCTAssertTrue(
            content.rows.contains(
                .init(label: "Bank 1 expires", value: "Aug 1, 04:19 (6d2h)")
            )
        )
        XCTAssertTrue(
            content.rows.contains(.init(label: "Updated", value: "Just now"))
        )
    }

    func testFormatsTraditionalChineseContent() {
        let content = formatter.content(
            snapshot: fullSnapshot,
            now: now,
            language: .traditionalChinese,
            timeZone: timeZone
        )

        XCTAssertEqual(content.title, "Codex 剩餘額度")
        XCTAssertEqual(content.informationEntry.title, "Tibo 的 X 動態")
        XCTAssertEqual(
            content.informationEntry.accessibilityLabel,
            "在瀏覽器中開啟 Tibo 的 X 主頁"
        )
        XCTAssertTrue(content.rows.contains(.init(label: "方案", value: "Plus")))
        XCTAssertTrue(content.rows.contains(.init(label: "額度週期", value: "7 天")))
        XCTAssertTrue(
            content.rows.contains(
                .init(
                    label: "下次重設",
                    value: "7天6小時（2026/08/02 08:00）",
                    valueStyle: .resetCountdown
                )
            )
        )
        XCTAssertTrue(
            content.rows.contains(
                .init(label: "Bank 1到期時間", value: "8月1日 04:19（6d2h）")
            )
        )
    }

    func testFormatsLocalizedTokenUsageAndResetCountdown() {
        let now = date(year: 2025, month: 8, day: 14, hour: 20, minute: 30)
        let reset = date(year: 2025, month: 8, day: 19, hour: 19, minute: 30)
        let allowance = AllowanceSnapshot(
            usedPercent: 68,
            remainingPercent: 32,
            resetsAt: reset,
            receivedAt: now,
            windowDurationMins: 10_080
        )
        let usageNow = date(year: 2025, month: 8, day: 25, hour: 20, minute: 30)
        let usageAllowance = AllowanceSnapshot(
            usedPercent: 68,
            remainingPercent: 32,
            resetsAt: date(year: 2025, month: 8, day: 26, hour: 19, minute: 30),
            receivedAt: usageNow,
            windowDurationMins: 10_080
        )
        let usage = TokenUsageSnapshot(
            receivedAt: usageNow,
            dailyBuckets: [
                TokenUsageDay(
                    date: date(year: 2025, month: 8, day: 19),
                    tokens: 240_000,
                    timeZone: timeZone
                ),
                TokenUsageDay(
                    date: date(year: 2025, month: 8, day: 25),
                    tokens: 1_000_000,
                    timeZone: timeZone
                )
            ],
            summary: nil,
            availability: .available
        )

        let resetSimplified = formatter.content(
            snapshot: allowance,
            now: now,
            language: .simplifiedChinese,
            timeZone: timeZone
        )
        let resetTraditional = formatter.content(
            snapshot: allowance,
            now: now,
            language: .traditionalChinese,
            timeZone: timeZone
        )
        let resetEnglish = formatter.content(
            snapshot: allowance,
            now: now,
            language: .english,
            timeZone: timeZone
        )

        let simplified = formatter.content(
            snapshot: usageAllowance,
            tokenUsage: usage,
            now: usageNow,
            language: .simplifiedChinese,
            timeZone: timeZone
        )
        let traditional = formatter.content(
            snapshot: usageAllowance,
            tokenUsage: usage,
            now: usageNow,
            language: .traditionalChinese,
            timeZone: timeZone
        )
        let english = formatter.content(
            snapshot: usageAllowance,
            tokenUsage: usage,
            now: usageNow,
            language: .english,
            timeZone: timeZone
        )

        XCTAssertTrue(resetSimplified.rows.contains {
            $0.label == "下次重置" &&
                $0.value == "4天23小时（2025/08/19 19:30）"
        })
        XCTAssertTrue(resetTraditional.rows.contains {
            $0.label == "下次重設" &&
                $0.value == "4天23小時（2025/08/19 19:30）"
        })
        XCTAssertTrue(resetEnglish.rows.contains {
            $0.label == "Next reset" &&
                $0.value == "4d 23h (2025/08/19 19:30)"
        })

        XCTAssertEqual(
            simplified.tokenUsage,
            QuotaTokenUsagePresentation(
                title: "Token 用量",
                totalLabel: "本周期总计 1.24M tokens",
                totalTokens: 1_240_000,
                days: [
                    .init(label: "8月19日", tokens: 240_000, isCurrentDay: false),
                    .init(label: "8月20日", tokens: 0, isCurrentDay: false),
                    .init(label: "8月21日", tokens: 0, isCurrentDay: false),
                    .init(label: "8月22日", tokens: 0, isCurrentDay: false),
                    .init(label: "8月23日", tokens: 0, isCurrentDay: false),
                    .init(label: "8月24日", tokens: 0, isCurrentDay: false),
                    .init(label: "8月25日", tokens: 1_000_000, isCurrentDay: true)
                ],
                delayNote: "使用数据最多可能延迟 6 小时",
                availability: .available
            )
        )
        XCTAssertEqual(english.tokenUsage?.title, "Token usage")
        XCTAssertEqual(english.tokenUsage?.totalLabel, "Current period total 1.24M tokens")
        XCTAssertEqual(english.tokenUsage?.days.map(\.label), [
            "Aug 19", "Aug 20", "Aug 21", "Aug 22", "Aug 23", "Aug 24", "Aug 25"
        ])
        XCTAssertEqual(traditional.tokenUsage?.title, "Token 用量")
        XCTAssertEqual(traditional.tokenUsage?.totalLabel, "本週期總計 1.24M tokens")
    }

    func testTokenUsageChartKeepsSevenCycleSlotsWhenOnlyThreeDaysHaveElapsed() {
        let now = date(year: 2026, month: 8, day: 15, hour: 20)
        let allowance = AllowanceSnapshot(
            usedPercent: 50,
            remainingPercent: 50,
            resetsAt: date(year: 2026, month: 8, day: 20, hour: 19, minute: 31),
            receivedAt: now,
            windowDurationMins: 10_080
        )
        let usage = TokenUsageSnapshot(
            receivedAt: now,
            dailyBuckets: [
                TokenUsageDay(
                    date: date(year: 2026, month: 8, day: 13),
                    tokens: 1_200,
                    timeZone: timeZone
                )
            ],
            summary: nil,
            availability: .available
        )

        let content = formatter.content(
            snapshot: allowance,
            tokenUsage: usage,
            now: now,
            language: .simplifiedChinese,
            timeZone: timeZone
        )

        XCTAssertEqual(content.tokenUsage?.totalTokens, 1_200)
        XCTAssertEqual(content.tokenUsage?.days.map(\.tokens), [1_200, 0, 0, 0, 0, 0, 0])
        XCTAssertEqual(content.tokenUsage?.days.map(\.label), [
            "8月13日", "8月14日", "8月15日", "8月16日",
            "8月17日", "8月18日", "8月19日"
        ])
    }

    func testUnavailableTokenUsageKeepsSevenEmptyReferenceSlots() {
        let now = date(year: 2026, month: 8, day: 15, hour: 20)
        let content = formatter.content(
            snapshot: allowance(
                resetsAt: date(year: 2026, month: 8, day: 20, hour: 19),
                receivedAt: now,
                windowDurationMins: 10_080
            ),
            tokenUsage: tokenUsage(availability: .unavailable, receivedAt: now),
            now: now,
            language: .english,
            timeZone: timeZone
        )

        XCTAssertEqual(content.tokenUsage?.availability, .unavailable)
        XCTAssertEqual(content.tokenUsage?.totalTokens, 0)
        XCTAssertEqual(content.tokenUsage?.totalLabel, "Current-period token usage is unavailable")
        XCTAssertEqual(content.tokenUsage?.delayNote, "Current-period token usage is unavailable")
        XCTAssertEqual(content.tokenUsage?.days.count, 7)
        XCTAssertEqual(content.tokenUsage?.days.map(\.tokens), Array(repeating: 0, count: 7))
    }

    func testUnsupportedTokenUsageKeepsSevenEmptyReferenceSlots() {
        let now = date(year: 2026, month: 8, day: 15, hour: 20)
        let content = formatter.content(
            snapshot: allowance(
                resetsAt: date(year: 2026, month: 8, day: 20, hour: 19),
                receivedAt: now,
                windowDurationMins: 10_080
            ),
            tokenUsage: tokenUsage(availability: .unsupported, receivedAt: now),
            now: now,
            language: .english,
            timeZone: timeZone
        )

        XCTAssertEqual(content.tokenUsage?.availability, .unsupported)
        XCTAssertEqual(content.tokenUsage?.totalTokens, 0)
        XCTAssertEqual(content.tokenUsage?.totalLabel, "Current-period token usage is unavailable")
        XCTAssertEqual(content.tokenUsage?.delayNote, "Current-period token usage is unavailable")
        XCTAssertEqual(content.tokenUsage?.days.count, 7)
        XCTAssertEqual(content.tokenUsage?.days.map(\.tokens), Array(repeating: 0, count: 7))
    }

    func testTokenUsageWithoutAValidWindowKeepsSevenCurrentEndingEmptySlots() {
        let now = date(year: 2026, month: 8, day: 15, hour: 20)
        let content = formatter.content(
            snapshot: allowance(
                resetsAt: date(year: 2026, month: 8, day: 20, hour: 19),
                receivedAt: now,
                windowDurationMins: nil
            ),
            tokenUsage: tokenUsage(availability: .available, receivedAt: now),
            now: now,
            language: .english,
            timeZone: timeZone
        )

        XCTAssertEqual(content.tokenUsage?.availability, .unavailable)
        XCTAssertEqual(content.tokenUsage?.totalTokens, 0)
        XCTAssertEqual(content.tokenUsage?.totalLabel, "Current-period token usage is unavailable")
        XCTAssertEqual(content.tokenUsage?.delayNote, "Current-period token usage is unavailable")
        XCTAssertEqual(content.tokenUsage?.days.map(\.tokens), Array(repeating: 0, count: 7))
        XCTAssertEqual(content.tokenUsage?.days.map(\.label), [
            "Aug 9", "Aug 10", "Aug 11", "Aug 12", "Aug 13", "Aug 14", "Aug 15"
        ])
        XCTAssertEqual(content.tokenUsage?.days.filter(\.isCurrentDay).count, 1)
        XCTAssertEqual(content.tokenUsage?.days.last?.isCurrentDay, true)
    }

    private var fullSnapshot: AllowanceSnapshot {
        snapshot(
            bank: BankResetSummary(
                availableCount: 2,
                credits: [
                    BankResetCredit(
                        status: "available",
                        grantedAt: Date(timeIntervalSince1970: 1_782_937_171),
                        expiresAt: Date(timeIntervalSince1970: 1_785_529_171),
                        title: "Full reset",
                        description: nil
                    ),
                    BankResetCredit(
                        status: "available",
                        grantedAt: Date(timeIntervalSince1970: 1_783_965_641),
                        expiresAt: Date(timeIntervalSince1970: 1_786_557_641),
                        title: "Full reset",
                        description: nil
                    )
                ]
            )
        )
    }

    private var dualWindowSnapshot: AllowanceSnapshot {
        AllowanceSnapshot(
            usedPercent: 15,
            remainingPercent: 85,
            resetsAt: Date(timeIntervalSince1970: 1_787_727_330),
            receivedAt: now.addingTimeInterval(-20),
            windowDurationMins: 300,
            planType: "plus",
            credits: CreditBalance(
                hasCredits: false,
                unlimited: false,
                balance: "0"
            ),
            bank: nil,
            secondary: QuotaWindowSnapshot(
                usedPercent: 2,
                remainingPercent: 98,
                resetsAt: Date(timeIntervalSince1970: 1_788_220_800),
                windowDurationMins: 10_080
            )
        )
    }

    private func snapshot(bank: BankResetSummary?) -> AllowanceSnapshot {
        AllowanceSnapshot(
            usedPercent: 24,
            remainingPercent: 76,
            resetsAt: Date(timeIntervalSince1970: 1_785_628_824),
            receivedAt: now.addingTimeInterval(-20),
            windowDurationMins: 10_080,
            planType: "plus",
            credits: CreditBalance(
                hasCredits: true,
                unlimited: false,
                balance: "12.50"
            ),
            bank: bank
        )
    }

    private func allowance(
        resetsAt: Date,
        receivedAt: Date,
        windowDurationMins: Int?
    ) -> AllowanceSnapshot {
        AllowanceSnapshot(
            usedPercent: 50,
            remainingPercent: 50,
            resetsAt: resetsAt,
            receivedAt: receivedAt,
            windowDurationMins: windowDurationMins
        )
    }

    private func tokenUsage(
        availability: TokenUsageAvailability,
        receivedAt: Date
    ) -> TokenUsageSnapshot {
        TokenUsageSnapshot(
            receivedAt: receivedAt,
            dailyBuckets: [],
            summary: nil,
            availability: availability
        )
    }

    private func bankRows(in content: QuotaDetailContent) -> [QuotaDetailRow] {
        content.rows.filter {
            $0.label.range(
                of: #"^Bank \d+到期时间$"#,
                options: .regularExpression
            ) != nil
        }
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
        )!
    }
}
