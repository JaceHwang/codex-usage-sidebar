import Foundation

public struct CreditBalance: Equatable, Sendable {
    public let hasCredits: Bool
    public let unlimited: Bool
    public let balance: String?

    public init(hasCredits: Bool, unlimited: Bool, balance: String?) {
        self.hasCredits = hasCredits
        self.unlimited = unlimited
        self.balance = balance
    }
}

public struct BankResetCredit: Equatable, Sendable {
    public let status: String?
    public let grantedAt: Date?
    public let expiresAt: Date?
    public let title: String?
    public let description: String?

    public init(
        status: String?,
        grantedAt: Date?,
        expiresAt: Date?,
        title: String?,
        description: String?
    ) {
        self.status = status
        self.grantedAt = grantedAt
        self.expiresAt = expiresAt
        self.title = title
        self.description = description
    }
}

public struct BankResetSummary: Equatable, Sendable {
    public let availableCount: Int
    public let credits: [BankResetCredit]?

    public init(availableCount: Int, credits: [BankResetCredit]?) {
        self.availableCount = availableCount
        self.credits = credits
    }
}

public struct AllowanceSnapshot: Equatable, Sendable {
    public let usedPercent: Double
    public let remainingPercent: Int
    public let resetsAt: Date
    public let receivedAt: Date
    public let windowDurationMins: Int?
    public let planType: String?
    public let credits: CreditBalance?
    public let bank: BankResetSummary?

    public init(
        usedPercent: Double,
        remainingPercent: Int,
        resetsAt: Date,
        receivedAt: Date,
        windowDurationMins: Int? = nil,
        planType: String? = nil,
        credits: CreditBalance? = nil,
        bank: BankResetSummary? = nil
    ) {
        self.usedPercent = usedPercent
        self.remainingPercent = remainingPercent
        self.resetsAt = resetsAt
        self.receivedAt = receivedAt
        self.windowDurationMins = windowDurationMins
        self.planType = planType
        self.credits = credits
        self.bank = bank
    }

    public func mergingSupplementary(from previous: AllowanceSnapshot?) -> AllowanceSnapshot {
        guard let previous else {
            return self
        }
        return AllowanceSnapshot(
            usedPercent: usedPercent,
            remainingPercent: remainingPercent,
            resetsAt: resetsAt,
            receivedAt: receivedAt,
            windowDurationMins: windowDurationMins ?? previous.windowDurationMins,
            planType: planType ?? previous.planType,
            credits: credits ?? previous.credits,
            bank: bank ?? previous.bank
        )
    }
}

public enum RateLimitDecodingError: Error, Equatable, Sendable {
    case invalidJSON
    case missingCodexBucket
    case missingUsedPercent
    case missingResetTime
    case invalidNumber
}

public enum TokenUsageAvailability: Equatable, Sendable {
    case available
    case unavailable
    case unsupported
}

public struct TokenUsageDay: Equatable, Sendable {
    public let date: Date
    public let tokens: Int64

    public init(date: Date, tokens: Int64, timeZone: TimeZone = .current) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.date = calendar.startOfDay(for: date)
        self.tokens = tokens
    }
}

public struct TokenUsageSummary: Equatable, Sendable {
    public let lifetimeTokens: Int64?
    public let peakDailyTokens: Int64?
    public let longestRunningTurnSec: Int?
    public let currentStreakDays: Int?
    public let longestStreakDays: Int?

    public init(
        lifetimeTokens: Int64?,
        peakDailyTokens: Int64?,
        longestRunningTurnSec: Int?,
        currentStreakDays: Int?,
        longestStreakDays: Int?
    ) {
        self.lifetimeTokens = lifetimeTokens
        self.peakDailyTokens = peakDailyTokens
        self.longestRunningTurnSec = longestRunningTurnSec
        self.currentStreakDays = currentStreakDays
        self.longestStreakDays = longestStreakDays
    }
}

public struct TokenUsageSnapshot: Equatable, Sendable {
    public let receivedAt: Date
    public let dailyBuckets: [TokenUsageDay]
    public let summary: TokenUsageSummary?
    public let availability: TokenUsageAvailability

    public init(
        receivedAt: Date,
        dailyBuckets: [TokenUsageDay],
        summary: TokenUsageSummary?,
        availability: TokenUsageAvailability
    ) {
        self.receivedAt = receivedAt
        self.dailyBuckets = dailyBuckets
        self.summary = summary
        self.availability = availability
    }
}

public struct TokenUsageCycle: Equatable, Sendable {
    public let dailyBuckets: [TokenUsageDay]
    public let totalTokens: Int64

    public init(dailyBuckets: [TokenUsageDay], totalTokens: Int64) {
        self.dailyBuckets = dailyBuckets
        self.totalTokens = totalTokens
    }
}

public enum TokenUsageDecodingError: Error, Equatable, Sendable {
    case invalidJSON
    case unavailable
    case unsupported
    case invalidDate
    case invalidTokens
    case invalidNumber
}
