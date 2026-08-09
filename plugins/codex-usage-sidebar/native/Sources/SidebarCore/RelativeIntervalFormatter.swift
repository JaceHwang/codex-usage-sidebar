import Foundation

public struct RelativeIntervalFormatter: Sendable {
    public init() {}

    public func string(from now: Date, to target: Date) -> String {
        let interval = target.timeIntervalSince(now)
        let totalSeconds = Int(abs(interval).rounded(.down))
        let value: String

        if totalSeconds >= 86_400 {
            let days = totalSeconds / 86_400
            let hours = totalSeconds % 86_400 / 3_600
            value = "\(days)天\(hours)小时"
        } else if totalSeconds >= 3_600 {
            let hours = totalSeconds / 3_600
            let minutes = totalSeconds % 3_600 / 60
            value = "\(hours)小时\(minutes)分钟"
        } else if totalSeconds >= 60 {
            value = "\(totalSeconds / 60)分钟"
        } else if interval < 0 {
            value = "不足1分钟前"
        } else {
            value = "不足1分钟"
        }

        guard interval < 0, totalSeconds >= 60 else {
            return value
        }
        return "\(value)前"
    }
}
