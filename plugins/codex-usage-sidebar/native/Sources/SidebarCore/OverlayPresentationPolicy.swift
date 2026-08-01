import Foundation

public enum SidebarChromeProbe: Equatable, Sendable {
    case skipped
    case unavailable
    case resolved(OverlayPlacement)
    case unresolved
}

public enum SidebarChromeTraversalOutcome: Equatable, Sendable {
    case complete
    case depthLimitReached
    case elementLimitReached
    case childReadFailed
}

public enum SidebarChromeCandidatePhaseOutcome: Equatable, Sendable {
    case complete
    case elementLimitReached
    case childReadFailed
}

public enum SidebarChromeScanContinuation: Equatable, Sendable {
    case finish(SidebarChromeProbe)
    case continueRendererTraversal
}

public enum SidebarChromeScanClassifier {
    public static func continuation(
        candidatePhaseOutcome: SidebarChromeCandidatePhaseOutcome,
        resolvedPlacement: OverlayPlacement?
    ) -> SidebarChromeScanContinuation {
        guard candidatePhaseOutcome == .complete else {
            return .finish(.unavailable)
        }
        if let resolvedPlacement {
            return .finish(.resolved(resolvedPlacement))
        }
        return .continueRendererTraversal
    }

    public static func probeAfterRendererTraversal(
        rendererRootObserved: Bool,
        traversalOutcome: SidebarChromeTraversalOutcome
    ) -> SidebarChromeProbe {
        guard rendererRootObserved, traversalOutcome == .complete else {
            return .unavailable
        }
        return .unresolved
    }
}

public enum OverlayPresentationDecision: Equatable, Sendable {
    case preserve
    case show(OverlayPlacement)
    case hide
}

public enum OverlayPresentationPolicy {
    public static func decision(
        for probe: SidebarChromeProbe
    ) -> OverlayPresentationDecision {
        switch probe {
        case .skipped, .unavailable:
            .preserve
        case let .resolved(placement):
            .show(placement)
        case .unresolved:
            .hide
        }
    }
}
