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

    public init(frame: CGRect, labels: [String]) {
        self.frame = frame
        self.labels = labels
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
    public static func stabilized(
        scanned: ContentHeaderAnchor,
        cached: ContentHeaderAnchor?
    ) -> ContentHeaderAnchor {
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
        let toolbarMinimumY = windowFrame.maxY - OverlayLayout.toolbarHeight

        let headerControls = controls.filter { control in
            let frame = control.frame
            return frame.width <= 160
                && frame.height <= OverlayLayout.toolbarHeight
                && frame.midY >= toolbarMinimumY
                && frame.midY <= windowFrame.maxY
                && frame.midX >= windowFrame.midX
        }

        let centralHeaderControls = headerControls.filter {
            $0.frame.maxX <= contentLimit + 1
        }

        if let openLocation = headerControls.filter(isOpenLocation).max(
            by: { $0.frame.minX < $1.frame.minX }
        ) {
            return ContentHeaderAnchor(
                trailingEdge: openLocation.frame.minX,
                source: .openLocation
            )
        }

        let labeledControl = centralHeaderControls.filter { control in
            control.frame.width >= 64
                && !control.labels.isEmpty
        }.max { lhs, rhs in
            lhs.frame.minX < rhs.frame.minX
        }
        if let labeledControl {
            return ContentHeaderAnchor(
                trailingEdge: labeledControl.frame.minX,
                source: .labeledControl
            )
        }

        if let paneBoundary {
            return ContentHeaderAnchor(
                trailingEdge: paneBoundary,
                source: .rightPaneBoundary
            )
        }
        return ContentHeaderAnchor(trailingEdge: nil, source: .fallback)
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
        let maximumPaneWidth = min(520, windowFrame.width * 0.42)
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
