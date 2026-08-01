import Foundation

public struct ResetFormatter: Sendable {
    public init() {}

    public func label(
        snapshot: AllowanceSnapshot,
        now _: Date,
        locale: Locale,
        timeZone: TimeZone,
        maxWidth: Double
    ) -> String {
        let format: String
        if maxWidth >= 130 {
            format = "M月d日 HH:mm"
        } else if maxWidth >= 90 {
            format = "EEE HH:mm"
        } else {
            format = "HH:mm"
        }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = format

        return "\(snapshot.remainingPercent)% · \(formatter.string(from: snapshot.resetsAt))"
    }
}
