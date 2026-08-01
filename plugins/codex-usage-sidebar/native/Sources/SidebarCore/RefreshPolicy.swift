import Foundation

public enum RefreshReason: Equatable, Sendable {
    case startup
    case focus
    case notification
    case timer
    case reset
    case hostBuildChanged
}

public enum SnapshotFreshness: Equatable, Sendable {
    case fresh
    case dimmed
    case hidden
}

public struct HostTransitionActions: Equatable, Sendable {
    public let invalidateAnchor: Bool
    public let restartClient: Bool

    public init(invalidateAnchor: Bool, restartClient: Bool) {
        self.invalidateAnchor = invalidateAnchor
        self.restartClient = restartClient
    }
}

public struct RefreshPolicy: Sendable {
    public let foregroundInterval: Duration = .seconds(1)
    public let backgroundInterval: Duration = .seconds(5)
    public let streamRecoveryAfter: TimeInterval = 12
    public let staleDimAfter: Duration = .seconds(120)
    public let staleHideAfter: Duration = .seconds(300)

    public init() {}

    public func interval(isHostForeground: Bool) -> Duration {
        isHostForeground ? foregroundInterval : backgroundInterval
    }

    public func intervalSeconds(isHostForeground: Bool) -> TimeInterval {
        isHostForeground ? 1 : 5
    }

    public func shouldRecoverStream(
        lastSnapshotAt: Date?,
        clientStartedAt: Date,
        now: Date
    ) -> Bool {
        let latestLivenessPoint = max(lastSnapshotAt ?? clientStartedAt, clientStartedAt)
        return now.timeIntervalSince(latestLivenessPoint) >= streamRecoveryAfter
    }

    public func shouldRefreshImmediately(for reason: RefreshReason) -> Bool {
        switch reason {
        case .startup, .focus, .reset, .hostBuildChanged:
            true
        case .notification, .timer:
            false
        }
    }

    public func nextResetRefresh(resetsAt: Date) -> Date {
        resetsAt.addingTimeInterval(2)
    }

    public func freshness(receivedAt: Date, now: Date) -> SnapshotFreshness {
        let age = max(0, now.timeIntervalSince(receivedAt))
        if age >= 300 {
            return .hidden
        }
        if age >= 120 {
            return .dimmed
        }
        return .fresh
    }

    public func actionsForHostTransition(
        from previousBuildIdentity: String?,
        to currentBuildIdentity: String?
    ) -> HostTransitionActions {
        let changed = previousBuildIdentity != nil &&
            currentBuildIdentity != nil &&
            previousBuildIdentity != currentBuildIdentity
        return HostTransitionActions(
            invalidateAnchor: changed,
            restartClient: changed
        )
    }
}
