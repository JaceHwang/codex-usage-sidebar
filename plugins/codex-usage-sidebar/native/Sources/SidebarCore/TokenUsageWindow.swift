import Foundation

public enum TokenUsageWindow {
    public static func currentCycle(
        from snapshot: TokenUsageSnapshot,
        allowance: AllowanceSnapshot,
        now: Date,
        timeZone: TimeZone
    ) -> TokenUsageCycle? {
        guard let durationMins = allowance.windowDurationMins, durationMins > 0 else {
            return nil
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let periodStart = allowance.resetsAt.addingTimeInterval(-Double(durationMins) * 60)
        let startDay = calendar.startOfDay(for: periodStart)
        let endDay = calendar.startOfDay(for: min(now, allowance.resetsAt))
        guard startDay <= endDay else {
            return TokenUsageCycle(dailyBuckets: [], totalTokens: 0)
        }

        var tokensByDay: [Date: Int64] = [:]
        for bucket in snapshot.dailyBuckets {
            let date = calendar.startOfDay(for: bucket.date)
            let (tokens, overflow) = (tokensByDay[date] ?? 0).addingReportingOverflow(bucket.tokens)
            guard !overflow else {
                return nil
            }
            tokensByDay[date] = tokens
        }
        var days: [TokenUsageDay] = []
        var totalTokens: Int64 = 0
        var day = startDay
        while day <= endDay {
            let tokens = tokensByDay[day] ?? 0
            let (nextTotal, overflow) = totalTokens.addingReportingOverflow(tokens)
            guard !overflow else {
                return nil
            }
            totalTokens = nextTotal
            days.append(TokenUsageDay(date: day, tokens: tokens, timeZone: timeZone))
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else {
                break
            }
            day = nextDay
        }
        return TokenUsageCycle(dailyBuckets: days, totalTokens: totalTokens)
    }
}
