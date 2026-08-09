import SidebarCore
import XCTest

final class QuotaLocalizationTests: XCTestCase {
    func testSimplifiedChineseCopy() {
        let copy = QuotaLocalization(language: .simplifiedChinese)

        XCTAssertEqual(copy.title, "Codex 剩余额度")
        XCTAssertEqual(copy.plan, "套餐")
        XCTAssertEqual(copy.quotaWindow, "额度周期")
        XCTAssertEqual(copy.nextReset, "下次重置")
        XCTAssertEqual(copy.bankAvailable, "Bank 可用重置")
        XCTAssertEqual(copy.bankExpiryLabel(2), "Bank 2到期时间")
        XCTAssertEqual(copy.bankDetails, "Bank 明细")
        XCTAssertEqual(copy.updated, "数据更新")
        XCTAssertEqual(copy.noData, "暂无数据")
        XCTAssertEqual(copy.locale.identifier, "zh_CN")
    }

    func testTraditionalChineseCopy() {
        let copy = QuotaLocalization(language: .traditionalChinese)

        XCTAssertEqual(copy.title, "Codex 剩餘額度")
        XCTAssertEqual(copy.plan, "方案")
        XCTAssertEqual(copy.quotaWindow, "額度週期")
        XCTAssertEqual(copy.nextReset, "下次重設")
        XCTAssertEqual(copy.bankAvailable, "Bank 可用重設")
        XCTAssertEqual(copy.bankExpiryLabel(2), "Bank 2到期時間")
        XCTAssertEqual(copy.bankDetails, "Bank 詳情")
        XCTAssertEqual(copy.updated, "資料更新")
        XCTAssertEqual(copy.noData, "暫無資料")
        XCTAssertEqual(copy.locale.identifier, "zh_TW")
    }

    func testEnglishCopyAndPluralization() {
        let copy = QuotaLocalization(language: .english)

        XCTAssertEqual(copy.title, "Codex quota")
        XCTAssertEqual(copy.plan, "Plan")
        XCTAssertEqual(copy.quotaWindow, "Quota window")
        XCTAssertEqual(copy.nextReset, "Next reset")
        XCTAssertEqual(copy.bankAvailable, "Bank resets available")
        XCTAssertEqual(copy.bankExpiryLabel(2), "Bank 2 expires")
        XCTAssertEqual(copy.bankDetails, "Bank details")
        XCTAssertEqual(copy.updated, "Updated")
        XCTAssertEqual(copy.noData, "No data")
        XCTAssertEqual(copy.bankCount(1), "1 reset")
        XCTAssertEqual(copy.bankCount(2), "2 resets")
        XCTAssertEqual(copy.period(minutes: 1_440), "1 day")
        XCTAssertEqual(copy.period(minutes: 2_880), "2 days")
        XCTAssertEqual(copy.period(minutes: 60), "1 hour")
        XCTAssertEqual(copy.period(minutes: 120), "2 hours")
        XCTAssertEqual(copy.period(minutes: 30), "30 minutes")
        XCTAssertEqual(copy.locale.identifier, "en_US_POSIX")
    }

    func testCreditStatusAndFreshnessCopyInEveryLanguage() {
        let simplified = QuotaLocalization(language: .simplifiedChinese)
        let traditional = QuotaLocalization(language: .traditionalChinese)
        let english = QuotaLocalization(language: .english)

        XCTAssertEqual(simplified.noExpiry, "未提供到期时间")
        XCTAssertEqual(traditional.noExpiry, "未提供到期時間")
        XCTAssertEqual(english.noExpiry, "No expiry provided")
        XCTAssertEqual(simplified.used, "已使用")
        XCTAssertEqual(traditional.expired, "已過期")
        XCTAssertEqual(english.unlimited, "Unlimited")
        XCTAssertEqual(english.available, "Available")
        XCTAssertEqual(english.none, "None")
        XCTAssertEqual(simplified.freshness(minutes: 2), "2 分钟前")
        XCTAssertEqual(traditional.freshness(hours: 3), "3 小時前")
        XCTAssertEqual(english.freshness(minutes: 1), "1 minute ago")
        XCTAssertEqual(english.freshness(hours: 2), "2 hours ago")
    }
}
