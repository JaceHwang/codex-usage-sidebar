import CoreGraphics
import Foundation

public struct AnchorCandidate: Equatable, Sendable {
    public let frame: CGRect
    public let role: String
    public let childRoles: Set<String>
    public let siblingFrames: [CGRect]

    public init(
        frame: CGRect,
        role: String,
        childRoles: Set<String>,
        siblingFrames: [CGRect]
    ) {
        self.frame = frame
        self.role = role
        self.childRoles = childRoles
        self.siblingFrames = siblingFrames
    }
}

public enum AnchorScorer {
    private static let minimumScore = 16
    private static let requiredWinningMargin = 3

    public static func bestCandidate(
        in candidates: [AnchorCandidate],
        window: CGRect
    ) -> AnchorCandidate? {
        let ranked = candidates
            .compactMap { candidate -> (AnchorCandidate, Int)? in
                let score = score(candidate, window: window)
                return score >= minimumScore ? (candidate, score) : nil
            }
            .sorted { lhs, rhs in
                lhs.1 > rhs.1
            }

        guard let winner = ranked.first else {
            return nil
        }
        if ranked.count > 1, winner.1 - ranked[1].1 < requiredWinningMargin {
            return nil
        }
        return winner.0
    }

    private static func score(_ candidate: AnchorCandidate, window: CGRect) -> Int {
        guard
            candidate.frame.width >= 90,
            candidate.frame.height >= 26,
            candidate.frame.height <= 64,
            candidate.frame.intersects(window)
        else {
            return 0
        }

        var value = 0
        if candidate.role == "AXButton" {
            value += 4
        } else if candidate.role == "AXGroup" {
            value += 1
        }

        let bottomGap = abs(window.minY - candidate.frame.minY)
        if bottomGap <= 28 {
            value += 5
        } else if bottomGap <= 80 {
            value += 2
        }

        let leftBoundary = window.minX + window.width * 0.45
        if candidate.frame.midX <= leftBoundary {
            value += 3
        }

        value += 2
        if candidate.frame.width >= 140 {
            value += 4
        } else if candidate.frame.width >= 100 {
            value += 2
        }

        if candidate.childRoles.contains("AXImage") {
            value += 2
        }
        if candidate.childRoles.contains("AXStaticText") {
            value += 2
        }

        let hasNearbySmallSibling = candidate.siblingFrames.contains { sibling in
            sibling.width <= 48 &&
                sibling.height <= 48 &&
                abs(sibling.midY - candidate.frame.midY) <= 20 &&
                sibling.minX >= candidate.frame.maxX - 8
        }
        if hasNearbySmallSibling {
            value += 1
        }
        return value
    }
}

public struct AnchorCache: Sendable {
    private var buildIdentity: String?
    private var storedCandidate: AnchorCandidate?

    public init() {}

    public mutating func store(
        _ candidate: AnchorCandidate,
        buildIdentity: String
    ) {
        self.buildIdentity = buildIdentity
        storedCandidate = candidate
    }

    public mutating func candidate(buildIdentity: String) -> AnchorCandidate? {
        guard self.buildIdentity == buildIdentity else {
            self.buildIdentity = nil
            storedCandidate = nil
            return nil
        }
        return storedCandidate
    }

    public mutating func invalidate() {
        buildIdentity = nil
        storedCandidate = nil
    }
}
