import Foundation

public struct ResetFormatter: Sendable {
    public init() {}

    public func label(
        snapshot: AllowanceSnapshot,
        now _: Date,
        language: CodexDisplayLanguage,
        timeZone: TimeZone,
        maxWidth: Double
    ) -> String {
        let localization = QuotaLocalization(language: language)
        let format: String
        if maxWidth >= 130 {
            format = localization.fullIndicatorDateFormat
        } else if maxWidth >= 90 {
            format = "EEE HH:mm"
        } else {
            format = "HH:mm"
        }

        let formatter = DateFormatter()
        formatter.locale = localization.locale
        formatter.timeZone = timeZone
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = format

        return "\(snapshot.remainingPercent)% · \(formatter.string(from: snapshot.resetsAt))"
    }
}
