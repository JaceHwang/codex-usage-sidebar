import Foundation

public struct QuotaLocalization: Sendable {
    public let language: CodexDisplayLanguage

    public init(language: CodexDisplayLanguage) {
        self.language = language
    }

    public var locale: Locale {
        switch language {
        case .simplifiedChinese:
            Locale(identifier: "zh_CN")
        case .traditionalChinese:
            Locale(identifier: "zh_TW")
        case .english:
            Locale(identifier: "en_US_POSIX")
        }
    }

    public var title: String {
        switch language {
        case .simplifiedChinese: "Codex 剩余额度"
        case .traditionalChinese: "Codex 剩餘額度"
        case .english: "Codex quota"
        }
    }

    public var plan: String {
        switch language {
        case .simplifiedChinese: "套餐"
        case .traditionalChinese: "方案"
        case .english: "Plan"
        }
    }

    public var quotaWindow: String {
        switch language {
        case .simplifiedChinese: "额度周期"
        case .traditionalChinese: "額度週期"
        case .english: "Quota window"
        }
    }

    public var nextReset: String {
        switch language {
        case .simplifiedChinese: "下次重置"
        case .traditionalChinese: "下次重設"
        case .english: "Next reset"
        }
    }

    public var bankAvailable: String {
        switch language {
        case .simplifiedChinese: "Bank 可用重置"
        case .traditionalChinese: "Bank 可用重設"
        case .english: "Bank resets available"
        }
    }

    public func bankExpiryLabel(_ index: Int) -> String {
        switch language {
        case .simplifiedChinese: "Bank \(index)到期时间"
        case .traditionalChinese: "Bank \(index)到期時間"
        case .english: "Bank \(index) expires"
        }
    }

    public var bankDetails: String {
        switch language {
        case .simplifiedChinese: "Bank 明细"
        case .traditionalChinese: "Bank 詳情"
        case .english: "Bank details"
        }
    }

    public var updated: String {
        switch language {
        case .simplifiedChinese: "数据更新"
        case .traditionalChinese: "資料更新"
        case .english: "Updated"
        }
    }

    public var noData: String {
        switch language {
        case .simplifiedChinese: "暂无数据"
        case .traditionalChinese: "暫無資料"
        case .english: "No data"
        }
    }

    public var unlimited: String {
        switch language {
        case .simplifiedChinese: "无限"
        case .traditionalChinese: "無限"
        case .english: "Unlimited"
        }
    }

    public var available: String {
        switch language {
        case .simplifiedChinese: "可用"
        case .traditionalChinese: "可用"
        case .english: "Available"
        }
    }

    public var none: String {
        switch language {
        case .simplifiedChinese: "无"
        case .traditionalChinese: "無"
        case .english: "None"
        }
    }

    public var noExpiry: String {
        switch language {
        case .simplifiedChinese: "未提供到期时间"
        case .traditionalChinese: "未提供到期時間"
        case .english: "No expiry provided"
        }
    }

    public var used: String {
        switch language {
        case .simplifiedChinese: "已使用"
        case .traditionalChinese: "已使用"
        case .english: "Used"
        }
    }

    public var expired: String {
        switch language {
        case .simplifiedChinese: "已过期"
        case .traditionalChinese: "已過期"
        case .english: "Expired"
        }
    }

    public var justNow: String {
        switch language {
        case .simplifiedChinese: "刚刚"
        case .traditionalChinese: "剛剛"
        case .english: "Just now"
        }
    }

    public var detailDateFormat: String {
        language == .english ? "MMM d, HH:mm" : "M月d日 HH:mm"
    }

    public var fullIndicatorDateFormat: String {
        detailDateFormat
    }

    public var openingParenthesis: String {
        language == .english ? " (" : "（"
    }

    public var closingParenthesis: String {
        language == .english ? ")" : "）"
    }

    public var pastSuffix: String {
        language == .english ? " ago" : "前"
    }

    public func bankCount(_ count: Int) -> String {
        switch language {
        case .simplifiedChinese, .traditionalChinese:
            "\(count) 次"
        case .english:
            "\(count) \(count == 1 ? "reset" : "resets")"
        }
    }

    public func period(minutes: Int) -> String {
        if minutes.isMultiple(of: 1_440) {
            return duration(
                minutes / 1_440,
                simplified: "天",
                traditional: "天",
                english: "day"
            )
        }
        if minutes.isMultiple(of: 60) {
            return duration(
                minutes / 60,
                simplified: "小时",
                traditional: "小時",
                english: "hour"
            )
        }
        return duration(
            minutes,
            simplified: "分钟",
            traditional: "分鐘",
            english: "minute"
        )
    }

    public func freshness(minutes: Int) -> String {
        switch language {
        case .simplifiedChinese:
            "\(minutes) 分钟前"
        case .traditionalChinese:
            "\(minutes) 分鐘前"
        case .english:
            "\(minutes) \(minutes == 1 ? "minute" : "minutes") ago"
        }
    }

    public func freshness(hours: Int) -> String {
        switch language {
        case .simplifiedChinese:
            "\(hours) 小时前"
        case .traditionalChinese:
            "\(hours) 小時前"
        case .english:
            "\(hours) \(hours == 1 ? "hour" : "hours") ago"
        }
    }

    private func duration(
        _ value: Int,
        simplified: String,
        traditional: String,
        english: String
    ) -> String {
        switch language {
        case .simplifiedChinese:
            "\(value) \(simplified)"
        case .traditionalChinese:
            "\(value) \(traditional)"
        case .english:
            "\(value) \(english)\(value == 1 ? "" : "s")"
        }
    }
}
