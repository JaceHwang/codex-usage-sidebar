import Foundation

public struct SidebarProbeGate: Sendable {
    private let settlingInterval: TimeInterval
    private var suppressedUntil = Date.distantPast

    public init(settlingInterval: TimeInterval = 0.35) {
        self.settlingInterval = settlingInterval
    }

    public mutating func observeHint(at date: Date) {
        suppressedUntil = date.addingTimeInterval(settlingInterval)
    }

    public func shouldProbe(at date: Date) -> Bool {
        date >= suppressedUntil
    }
}
