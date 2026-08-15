import Foundation

public struct QuotaDetailRow: Equatable, Sendable {
    public let label: String
    public let value: String

    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }
}

public struct QuotaInformationEntry: Equatable, Sendable {
    public let title: String
    public let accessibilityLabel: String
    public let destination: URL

    public init(
        title: String,
        accessibilityLabel: String,
        destination: URL
    ) {
        self.title = title
        self.accessibilityLabel = accessibilityLabel
        self.destination = destination
    }
}

public struct QuotaDetailContent: Equatable, Sendable {
    public let title: String
    public let remainingPercent: Int
    public let informationEntry: QuotaInformationEntry
    public let rows: [QuotaDetailRow]

    public init(
        title: String,
        remainingPercent: Int,
        informationEntry: QuotaInformationEntry,
        rows: [QuotaDetailRow]
    ) {
        self.title = title
        self.remainingPercent = remainingPercent
        self.informationEntry = informationEntry
        self.rows = rows
    }
}

public struct QuotaDetailFormatter: Sendable {
    private static let tiboProfileURL = URL(
        string: "https://x.com/thsottiaux"
    )!
    private let relativeIntervalFormatter = RelativeIntervalFormatter()

    public init() {}

    public func content(
        snapshot: AllowanceSnapshot,
        now: Date,
        language: CodexDisplayLanguage,
        timeZone: TimeZone
    ) -> QuotaDetailContent {
        let copy = QuotaLocalization(language: language)
        var rows: [QuotaDetailRow] = []

        if let planType = snapshot.planType, !planType.isEmpty {
            rows.append(.init(label: copy.plan, value: displayPlan(planType)))
        }
        if let minutes = snapshot.windowDurationMins, minutes > 0 {
            rows.append(
                .init(
                    label: copy.quotaWindow,
                    value: copy.period(minutes: minutes)
                )
            )
        }
        rows.append(
            .init(
                label: copy.nextReset,
                value: displayDateWithInterval(
                    snapshot.resetsAt,
                    now: now,
                    copy: copy,
                    timeZone: timeZone
                )
            )
        )
        rows.append(
            .init(
                label: "Credits",
                value: displayCredits(snapshot.credits, copy: copy)
            )
        )

        if let bank = snapshot.bank {
            rows.append(
                .init(
                    label: copy.bankAvailable,
                    value: copy.bankCount(bank.availableCount)
                )
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
                        label: copy.bankExpiryLabel(index + 1),
                        value: displayBankExpiry(
                            item.element,
                            now: now,
                            copy: copy,
                            timeZone: timeZone
                        )
                    )
                )
            }
            if credits.isEmpty, bank.availableCount > 0 {
                rows.append(.init(label: copy.bankDetails, value: copy.noData))
            }
        } else {
            rows.append(.init(label: copy.bankAvailable, value: copy.noData))
        }

        rows.append(
            .init(
                label: copy.updated,
                value: displayFreshness(
                    snapshot.receivedAt,
                    now: now,
                    copy: copy
                )
            )
        )

        return QuotaDetailContent(
            title: copy.title,
            remainingPercent: snapshot.remainingPercent,
            informationEntry: QuotaInformationEntry(
                title: copy.tiboXTitle,
                accessibilityLabel: copy.tiboXAccessibilityLabel,
                destination: Self.tiboProfileURL
            ),
            rows: rows
        )
    }

    private func displayPlan(_ value: String) -> String {
        value.prefix(1).uppercased() + value.dropFirst()
    }

    private func displayCredits(
        _ credits: CreditBalance?,
        copy: QuotaLocalization
    ) -> String {
        guard let credits else {
            return copy.noData
        }
        if credits.unlimited {
            return copy.unlimited
        }
        if credits.hasCredits {
            return credits.balance ?? copy.available
        }
        return copy.none
    }

    private func displayDate(
        _ date: Date,
        copy: QuotaLocalization,
        timeZone: TimeZone
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = copy.locale
        formatter.timeZone = timeZone
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = copy.detailDateFormat
        return formatter.string(from: date)
    }

    private func displayDateWithInterval(
        _ date: Date,
        now: Date,
        copy: QuotaLocalization,
        timeZone: TimeZone
    ) -> String {
        let absolute = displayDate(date, copy: copy, timeZone: timeZone)
        let relative = relativeIntervalFormatter.string(
            from: now,
            to: date,
            language: copy.language
        )
        return "\(absolute)\(copy.openingParenthesis)\(relative)" +
            copy.closingParenthesis
    }

    private func displayBankExpiry(
        _ credit: BankResetCredit,
        now: Date,
        copy: QuotaLocalization,
        timeZone: TimeZone
    ) -> String {
        let status = credit.status?.lowercased()
        guard let expiry = credit.expiresAt else {
            switch status {
            case "used":
                return "\(copy.noExpiry) · \(copy.used)"
            case "expired":
                return "\(copy.noExpiry) · \(copy.expired)"
            default:
                return copy.noExpiry
            }
        }
        let expiryDescription = displayDateWithInterval(
            expiry,
            now: now,
            copy: copy,
            timeZone: timeZone
        )
        switch status {
        case "used":
            return "\(expiryDescription) · \(copy.used)"
        case "expired":
            return "\(expiryDescription) · \(copy.expired)"
        default:
            return expiry <= now
                ? "\(expiryDescription) · \(copy.expired)"
                : expiryDescription
        }
    }

    private func displayFreshness(
        _ receivedAt: Date,
        now: Date,
        copy: QuotaLocalization
    ) -> String {
        let seconds = max(0, now.timeIntervalSince(receivedAt))
        if seconds < 60 {
            return copy.justNow
        }
        if seconds < 3_600 {
            return copy.freshness(minutes: Int(seconds / 60))
        }
        return copy.freshness(hours: Int(seconds / 3_600))
    }
}
