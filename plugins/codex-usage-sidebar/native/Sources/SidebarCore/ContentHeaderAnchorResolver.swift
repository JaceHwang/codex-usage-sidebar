import CoreGraphics
import Foundation

public enum ContentHeaderAnchorSource: String, Equatable, Sendable {
    case openLocation
    case labeledControl
    case rightPaneBoundary
    case fallback
}

public struct ContentHeaderControl: Equatable, Sendable {
    public let frame: CGRect
    public let labels: [String]
    public let isAnchorCandidate: Bool

    public init(
        frame: CGRect,
        labels: [String],
        isAnchorCandidate: Bool = true
    ) {
        self.frame = frame
        self.labels = labels
        self.isAnchorCandidate = isAnchorCandidate
    }
}

public struct ContentHeaderAnchor: Equatable, Sendable {
    public let trailingEdge: CGFloat?
    public let source: ContentHeaderAnchorSource

    public init(
        trailingEdge: CGFloat?,
        source: ContentHeaderAnchorSource
    ) {
        self.trailingEdge = trailingEdge
        self.source = source
    }
}

public enum ContentHeaderAnchorResolver {
    private static let maximumAnchorWidth: CGFloat = 160
    private static let minimumToolbarItemHeight: CGFloat = 8

    public static func shouldScanDescendants(
        of frame: CGRect,
        windowFrame: CGRect
    ) -> Bool {
        let scanMinimumX = windowFrame.midX
            - OverlayLayout.indicatorWidth
            - OverlayLayout.indicatorGap
            - maximumAnchorWidth / 2
        let scanMinimumY = windowFrame.maxY - OverlayLayout.toolbarHeight
        return frame.height >= minimumToolbarItemHeight
            && frame.maxX >= scanMinimumX
            && frame.maxY >= scanMinimumY
    }

    public static func isEligibleToolbarItem(
        frame: CGRect,
        windowFrame: CGRect
    ) -> Bool {
        let toolbarMinimumY = windowFrame.maxY - OverlayLayout.toolbarHeight
        return frame.width > 0
            && frame.height >= minimumToolbarItemHeight
            && frame.height <= OverlayLayout.toolbarHeight
            && frame.midY >= toolbarMinimumY
            && frame.midY <= windowFrame.maxY
            && frame.maxX >= windowFrame.minX
            && frame.minX <= windowFrame.maxX
    }

    public static func stabilized(
        scanned: ContentHeaderAnchor,
        cached: ContentHeaderAnchor?
    ) -> ContentHeaderAnchor {
        if scanned.source == .fallback, scanned.trailingEdge != nil {
            return scanned
        }
        guard
            scanned.source != .openLocation,
            let cached,
            cached.source == .openLocation,
            cached.trailingEdge != nil
        else {
            return scanned
        }
        return cached
    }

    public static func resolve(
        controls: [ContentHeaderControl],
        paneFrames: [CGRect],
        windowFrame: CGRect
    ) -> ContentHeaderAnchor {
        let paneBoundary = rightPaneLeadingEdge(
            paneFrames: paneFrames,
            windowFrame: windowFrame
        )
        let contentLimit = paneBoundary ?? windowFrame.maxX
        let toolbarItems = controls.filter { control in
            isEligibleToolbarItem(
                frame: control.frame,
                windowFrame: windowFrame
            )
        }

        let eligibleAnchorCandidates = toolbarItems.filter { control in
            let frame = control.frame
            return control.isAnchorCandidate
                && frame.width <= maximumAnchorWidth
        }

        let headerControls = eligibleAnchorCandidates.filter { control in
            let frame = control.frame
            return frame.midX >= windowFrame.midX
        }

        let centralHeaderControls = headerControls.filter {
            $0.frame.maxX <= contentLimit + 1
        }

        if let openLocation = eligibleAnchorCandidates.filter(isOpenLocation).max(
            by: { $0.frame.minX < $1.frame.minX }
        ) {
            return collisionAwareAnchor(
                trailingEdge: openLocation.frame.minX,
                source: .openLocation,
                selectedFrame: openLocation.frame,
                toolbarItems: toolbarItems,
                windowFrame: windowFrame
            )
        }

        let labeledControl = centralHeaderControls.filter { control in
            control.frame.width >= 64
                && !control.labels.isEmpty
        }.max { lhs, rhs in
            lhs.frame.minX < rhs.frame.minX
        }
        if let labeledControl {
            return collisionAwareAnchor(
                trailingEdge: labeledControl.frame.minX,
                source: .labeledControl,
                selectedFrame: labeledControl.frame,
                toolbarItems: toolbarItems,
                windowFrame: windowFrame
            )
        }

        if let paneBoundary {
            return collisionAwareAnchor(
                trailingEdge: paneBoundary,
                source: .rightPaneBoundary,
                selectedFrame: nil,
                toolbarItems: toolbarItems,
                windowFrame: windowFrame
            )
        }
        return ContentHeaderAnchor(trailingEdge: nil, source: .fallback)
    }

    private static func collisionAwareAnchor(
        trailingEdge: CGFloat,
        source: ContentHeaderAnchorSource,
        selectedFrame: CGRect?,
        toolbarItems: [ContentHeaderControl],
        windowFrame: CGRect
    ) -> ContentHeaderAnchor {
        let obstacles = toolbarItems.filter { item in
            guard let selectedFrame else {
                return true
            }
            return item.frame != selectedFrame
        }
        var resolvedEdge = trailingEdge

        for _ in 0...obstacles.count {
            let candidate = OverlayLayout.indicatorFrame(
                in: windowFrame,
                contentTrailingEdge: resolvedEdge
            )
            let collisions = obstacles.filter { item in
                candidate.intersects(
                    item.frame.insetBy(
                        dx: -OverlayLayout.indicatorGap,
                        dy: 0
                    )
                )
            }
            guard !collisions.isEmpty else {
                return ContentHeaderAnchor(
                    trailingEdge: resolvedEdge,
                    source: source
                )
            }
            if collisions.contains(where: { !$0.isAnchorCandidate }) {
                return trailingFallback(in: windowFrame)
            }
            guard
                let nextEdge = collisions.map(\.frame.minX).min(),
                nextEdge < resolvedEdge - 0.5
            else {
                return trailingFallback(in: windowFrame)
            }
            resolvedEdge = nextEdge
        }
        return trailingFallback(in: windowFrame)
    }

    private static func trailingFallback(
        in windowFrame: CGRect
    ) -> ContentHeaderAnchor {
        ContentHeaderAnchor(
            trailingEdge: OverlayLayout.trailingFallbackEdge(in: windowFrame),
            source: .fallback
        )
    }

    private static func isOpenLocation(
        _ control: ContentHeaderControl
    ) -> Bool {
        let text = control.labels
            .map(normalizedLabel)
            .joined(separator: " ")
        return text.contains("打开位置")
            || text.contains("open location")
            || text.contains("openlocation")
    }

    private static func normalizedLabel(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func rightPaneLeadingEdge(
        paneFrames: [CGRect],
        windowFrame: CGRect
    ) -> CGFloat? {
        let maximumPaneWidth = windowFrame.width * 0.75
        let toolbarMinimumY = windowFrame.maxY - OverlayLayout.toolbarHeight

        return paneFrames.filter { frame in
            frame.width >= 240
                && frame.width <= maximumPaneWidth
                && frame.height >= windowFrame.height * 0.45
                && abs(frame.maxX - windowFrame.maxX) <= 24
                && frame.minY <= windowFrame.minY + 96
                && frame.maxY >= toolbarMinimumY - 32
        }.map(\.minX).min()
    }
}
