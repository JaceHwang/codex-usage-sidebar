import Foundation
import XCTest
@testable import SidebarCore

final class QuotaDetailFormatterTests: XCTestCase {
    private let formatter = QuotaDetailFormatter()
    private let timeZone = TimeZone(identifier: "Asia/Shanghai")!
    private let now = Date(timeIntervalSince1970: 1_785_000_000)

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
                    value: "8月2日 08:00（7d6h）"
                )
            )
        )
        XCTAssertTrue(content.rows.contains(.init(label: "套餐", value: "Plus")))
        XCTAssertTrue(content.rows.contains(.init(label: "额度周期", value: "7 天")))
        XCTAssertTrue(content.rows.contains(.init(label: "Credits", value: "12.50")))
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
                .init(label: "Next reset", value: "Aug 2, 08:00 (7d6h)")
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
                .init(label: "下次重設", value: "8月2日 08:00（7d6h）")
            )
        )
        XCTAssertTrue(
            content.rows.contains(
                .init(label: "Bank 1到期時間", value: "8月1日 04:19（6d2h）")
            )
        )
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

    private func bankRows(in content: QuotaDetailContent) -> [QuotaDetailRow] {
        content.rows.filter {
            $0.label.range(
                of: #"^Bank \d+到期时间$"#,
                options: .regularExpression
            ) != nil
        }
    }
}
