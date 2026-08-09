import Foundation

public struct QuotaDetailRow: Equatable, Sendable {
    public let label: String
    public let value: String

    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }
}

public struct QuotaDetailContent: Equatable, Sendable {
    public let title: String
    public let remainingPercent: Int
    public let rows: [QuotaDetailRow]

    public init(
        title: String,
        remainingPercent: Int,
        rows: [QuotaDetailRow]
    ) {
        self.title = title
        self.remainingPercent = remainingPercent
        self.rows = rows
    }
}

public struct QuotaDetailFormatter: Sendable {
    private let relativeIntervalFormatter = RelativeIntervalFormatter()

    public init() {}

    public func content(
        snapshot: AllowanceSnapshot,
        now: Date,
        locale: Locale,
        timeZone: TimeZone
    ) -> QuotaDetailContent {
        var rows: [QuotaDetailRow] = []

        if let planType = snapshot.planType, !planType.isEmpty {
            rows.append(.init(label: "套餐", value: displayPlan(planType)))
        }
        if let minutes = snapshot.windowDurationMins, minutes > 0 {
            rows.append(.init(label: "额度周期", value: displayPeriod(minutes)))
        }
        rows.append(
            .init(
                label: "下次重置",
                value: displayDateWithInterval(
                    snapshot.resetsAt,
                    now: now,
                    locale: locale,
                    timeZone: timeZone
                )
            )
        )
        rows.append(
            .init(label: "Credits", value: displayCredits(snapshot.credits))
        )

        if let bank = snapshot.bank {
            rows.append(
                .init(label: "Bank 可用重置", value: "\(bank.availableCount) 次")
            )
            let credits = (bank.credits ?? []).enumerated().sorted {
                left,
                right in
                switch (left.element.expiresAt, right.element.expiresAt) {
                case let (.some(leftExpiry), .some(rightExpiry)):
                    if leftExpiry == rightExpiry {
                        return left.offset < right.offset
                    }
                    return leftExpiry < rightExpiry
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    return left.offset < right.offset
                }
            }
            for (index, item) in credits.enumerated() {
                rows.append(
                    .init(
                        label: "Bank \(index + 1)到期时间",
                        value: displayBankExpiry(
                            item.element,
                            now: now,
                            locale: locale,
                            timeZone: timeZone
                        )
                    )
                )
            }
            if credits.isEmpty, bank.availableCount > 0 {
                rows.append(.init(label: "Bank 明细", value: "暂无数据"))
            }
        } else {
            rows.append(.init(label: "Bank 可用重置", value: "暂无数据"))
        }

        rows.append(
            .init(
                label: "数据更新",
                value: displayFreshness(snapshot.receivedAt, now: now)
            )
        )

        return QuotaDetailContent(
            title: "Codex 剩余额度",
            remainingPercent: snapshot.remainingPercent,
            rows: rows
        )
    }

    private func displayPlan(_ value: String) -> String {
        value.prefix(1).uppercased() + value.dropFirst()
    }

    private func displayPeriod(_ minutes: Int) -> String {
        if minutes.isMultiple(of: 1_440) {
            return "\(minutes / 1_440) 天"
        }
        if minutes.isMultiple(of: 60) {
            return "\(minutes / 60) 小时"
        }
        return "\(minutes) 分钟"
    }

    private func displayCredits(_ credits: CreditBalance?) -> String {
        guard let credits else {
            return "暂无数据"
        }
        if credits.unlimited {
            return "无限"
        }
        if credits.hasCredits {
            return credits.balance ?? "可用"
        }
        return "无"
    }

    private func displayDate(
        _ date: Date,
        locale: Locale,
        timeZone: TimeZone
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: date)
    }

    private func displayDateWithInterval(
        _ date: Date,
        now: Date,
        locale: Locale,
        timeZone: TimeZone
    ) -> String {
        let absolute = displayDate(date, locale: locale, timeZone: timeZone)
        let relative = relativeIntervalFormatter.string(from: now, to: date)
        return "\(absolute)（\(relative)）"
    }

    private func displayBankExpiry(
        _ credit: BankResetCredit,
        now: Date,
        locale: Locale,
        timeZone: TimeZone
    ) -> String {
        let status = credit.status?.lowercased()
        guard let expiry = credit.expiresAt else {
            switch status {
            case "used":
                return "未提供到期时间 · 已使用"
            case "expired":
                return "未提供到期时间 · 已过期"
            default:
                return "未提供到期时间"
            }
        }
        let expiryDescription = displayDateWithInterval(
            expiry,
            now: now,
            locale: locale,
            timeZone: timeZone
        )
        switch status {
        case "used":
            return "\(expiryDescription) · 已使用"
        case "expired":
            return "\(expiryDescription) · 已过期"
        default:
            return expiry <= now
                ? "\(expiryDescription) · 已过期"
                : expiryDescription
        }
    }

    private func displayFreshness(_ receivedAt: Date, now: Date) -> String {
        let seconds = max(0, now.timeIntervalSince(receivedAt))
        if seconds < 60 {
            return "刚刚"
        }
        if seconds < 3_600 {
            return "\(Int(seconds / 60)) 分钟前"
        }
        return "\(Int(seconds / 3_600)) 小时前"
    }
}
