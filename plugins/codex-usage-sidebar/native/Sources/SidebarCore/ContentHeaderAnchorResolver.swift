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
    // Long localized labels (notably English and several CJK/European
    // locales) can make Codex's Open Location control wider than the compact
    // Chinese layout. Keep it eligible so the collision resolver can still
    // move the quota indicator to the right fallback slot.
    private static let maximumAnchorWidth: CGFloat = 240
    // The real titlebar never exposes a single interactive/text item wider
    // than the title cluster. A wider element at the toolbar Y coordinate is
    // normally a scrolled conversation surface crossing the titlebar.
    private static let maximumToolbarItemWidth: CGFloat = 420
    private static let initialScanAnchorWidth: CGFloat = 160
    private static let minimumToolbarItemHeight: CGFloat = 8

    public static func shouldScanDescendants(
        of frame: CGRect,
        windowFrame: CGRect,
        minimumX: CGFloat? = nil
    ) -> Bool {
        let scanMinimumX = minimumX ?? initialScanMinimumX(in: windowFrame)
        let scanMinimumY = windowFrame.maxY - OverlayLayout.toolbarHeight
        return frame.height >= minimumToolbarItemHeight
            && frame.maxX >= scanMinimumX
            && frame.maxY >= scanMinimumY
    }

    public static func initialScanMinimumX(in windowFrame: CGRect) -> CGFloat {
        windowFrame.midX
            - OverlayLayout.indicatorWidth
            - OverlayLayout.indicatorGap
            - initialScanAnchorWidth / 2
    }

    public static func expandedScanMinimumX(
        after anchor: ContentHeaderAnchor,
        currentMinimumX: CGFloat,
        windowFrame: CGRect
    ) -> CGFloat? {
        guard
            anchor.source != .fallback,
            let trailingEdge = anchor.trailingEdge
        else {
            return nil
        }
        let resolvedMinimumX = OverlayLayout.indicatorFrame(
            in: windowFrame,
            contentTrailingEdge: trailingEdge
        ).minX - OverlayLayout.indicatorGap
        let clampedMinimumX = max(windowFrame.minX, resolvedMinimumX)
        guard clampedMinimumX < currentMinimumX - 0.5 else {
            return nil
        }
        return clampedMinimumX
    }

    public static func fallbackIfScanIsIncomplete(
        anchor: ContentHeaderAnchor,
        currentMinimumX: CGFloat,
        windowFrame: CGRect
    ) -> ContentHeaderAnchor {
        guard expandedScanMinimumX(
            after: anchor,
            currentMinimumX: currentMinimumX,
            windowFrame: windowFrame
        ) != nil else {
            return anchor
        }
        return trailingFallback(in: windowFrame)
    }

    public static func isEligibleToolbarItem(
        frame: CGRect,
        windowFrame: CGRect,
        isAnchorCandidate: Bool = true
    ) -> Bool {
        let toolbarMinimumY = windowFrame.maxY - OverlayLayout.toolbarHeight
        return frame.width > 0
            && frame.height >= minimumToolbarItemHeight
            && frame.height <= OverlayLayout.toolbarHeight
            && (!isAnchorCandidate || frame.width <= maximumToolbarItemWidth)
            // Require the complete accessibility element to be inside the
            // toolbar band. A conversation card that is scrolled under the
            // titlebar can have its midpoint in this band while its bounds
            // still extend into the content area; accepting it makes its
            // children become false titlebar anchors/obstacles.
            && frame.minY >= toolbarMinimumY
            && frame.maxY <= windowFrame.maxY
            && frame.maxX >= windowFrame.minX
            && frame.minX <= windowFrame.maxX
    }

    /// Settings replaces the conversation surface with a separate page that
    /// exposes a compact back-navigation button in the upper-left content
    /// area. That button is the stable, localized signal that the quota
    /// indicator should be hidden until the user returns to a conversation.
    public static func isSettingsNavigationControl(
        _ control: ContentHeaderControl,
        windowFrame: CGRect,
        allowStructuralMatch: Bool = true
    ) -> Bool {
        let frame = control.frame
        guard
            frame.width > 0,
            frame.width <= 320,
            frame.height > 0,
            frame.height <= 64,
            frame.minX <= windowFrame.minX + windowFrame.width * 0.35,
            frame.maxY >= windowFrame.maxY - 120,
            frame.minY <= windowFrame.maxY
        else {
            return false
        }

        let labels = control.labels.map(normalizedLabel)
        if allowStructuralMatch, frame.width >= 100 {
            return true
        }
        return labels.contains("返回应用")
            || labels.contains("返回應用")
            || labels.contains("back to app")
            || (frame.width >= 100 && labels.contains("返回"))
    }

    /// Returns true when a scanned toolbar control is the conversation's
    /// Open Location control. This signal must survive collision fallback:
    /// the quota indicator can move to the right-side fallback slot while the
    /// page is still a conversation, not Settings.
    public static func isOpenLocationControl(
        _ control: ContentHeaderControl
    ) -> Bool {
        isOpenLocation(control)
    }

    /// Identifies the wide central toolbar controls used by the conversation
    /// surface even when their localized label is unknown. Keeping this
    /// structural signal separate from the resolved anchor lets a collision
    /// fall back to the right-side slot without being mistaken for Settings.
    public static func isConversationToolbarControl(
        _ control: ContentHeaderControl,
        windowFrame: CGRect
    ) -> Bool {
        guard control.isAnchorCandidate else {
            return false
        }
        let frame = control.frame
        return frame.width >= 64
            && frame.width <= maximumAnchorWidth
            && frame.minX >= initialScanMinimumX(in: windowFrame)
            && isEligibleToolbarItem(frame: frame, windowFrame: windowFrame)
    }

    public static func hasRightPane(
        paneFrames: [CGRect],
        windowFrame: CGRect
    ) -> Bool {
        rightPaneLeadingEdge(
            paneFrames: paneFrames,
            windowFrame: windowFrame
        ) != nil
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
        windowFrame: CGRect,
        indicatorWidth: CGFloat = OverlayLayout.indicatorWidth
    ) -> ContentHeaderAnchor {
        let paneBoundary = rightPaneLeadingEdge(
            paneFrames: paneFrames,
            windowFrame: windowFrame
        )
        let contentLimit = paneBoundary ?? windowFrame.maxX
        let toolbarItems = controls.filter { control in
            isEligibleToolbarItem(
                frame: control.frame,
                windowFrame: windowFrame,
                // AX extraction applies the interactive-width guard before a
                // control enters this resolver. Keep structural/static title
                // barriers available here even when they span a wider title
                // cluster.
                isAnchorCandidate: false
            )
        }

        let eligibleAnchorCandidates = toolbarItems.filter { control in
            let frame = control.frame
            return control.isAnchorCandidate
                && frame.width <= maximumAnchorWidth
        }

        let headerControls = eligibleAnchorCandidates.filter { control in
            let frame = control.frame
            return frame.minX >= initialScanMinimumX(in: windowFrame)
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
                windowFrame: windowFrame,
                indicatorWidth: indicatorWidth
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
                windowFrame: windowFrame,
                indicatorWidth: indicatorWidth
            )
        }

        if let paneBoundary {
            return collisionAwareAnchor(
                trailingEdge: paneBoundary,
                source: .rightPaneBoundary,
                selectedFrame: nil,
                toolbarItems: toolbarItems,
                windowFrame: windowFrame,
                indicatorWidth: indicatorWidth
            )
        }
        return ContentHeaderAnchor(trailingEdge: nil, source: .fallback)
    }

    private static func collisionAwareAnchor(
        trailingEdge: CGFloat,
        source: ContentHeaderAnchorSource,
        selectedFrame: CGRect?,
        toolbarItems: [ContentHeaderControl],
        windowFrame: CGRect,
        indicatorWidth: CGFloat
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
                contentTrailingEdge: resolvedEdge,
                width: indicatorWidth
            )
            if let selectedFrame {
                let expectedMaximumX = resolvedEdge - OverlayLayout.indicatorGap
                guard
                    abs(candidate.maxX - expectedMaximumX) <= 0.5,
                    !candidate.intersects(selectedFrame)
                else {
                    return trailingFallback(in: windowFrame)
                }
            }
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
            || text.contains("開啟位置")
            || text.contains("打開位置")
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
        // Codex can expand the right pane beyond 60% of a narrow central
        // surface. Keep the upper bound below a full-window group while still
        // recognizing that legitimate wide-pane state.
        let maximumPaneWidth = windowFrame.width * 0.72
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
