import CoreGraphics
import Foundation

public enum IndicatorPlacementMode: String, CaseIterable, Codable, Sendable {
    case automatic
    case free
    case locked

    public var usesManualFrame: Bool {
        self != .automatic
    }
}

public struct IndicatorManualPlacement: Codable, Equatable, Sendable {
    public let normalizedX: Double
    public let normalizedY: Double

    public init(normalizedX: Double, normalizedY: Double) {
        self.normalizedX = Self.clamped(normalizedX)
        self.normalizedY = Self.clamped(normalizedY)
    }

    public init(frame: CGRect, in visibleFrame: CGRect) {
        let available = Self.availableOriginRect(
            visibleFrame: visibleFrame,
            size: frame.size
        )
        self.init(
            normalizedX: Self.normalized(
                frame.minX,
                lowerBound: available.minX,
                upperBound: available.maxX
            ),
            normalizedY: Self.normalized(
                frame.minY,
                lowerBound: available.minY,
                upperBound: available.maxY
            )
        )
    }

    public func resolvedFrame(in visibleFrame: CGRect, size: CGSize) -> CGRect {
        let available = Self.availableOriginRect(
            visibleFrame: visibleFrame,
            size: size
        )
        return CGRect(
            x: available.minX + available.width * normalizedX,
            y: available.minY + available.height * normalizedY,
            width: size.width,
            height: size.height
        )
    }

    private static func availableOriginRect(
        visibleFrame: CGRect,
        size: CGSize
    ) -> CGRect {
        CGRect(
            x: visibleFrame.minX,
            y: visibleFrame.minY,
            width: max(0, visibleFrame.width - size.width),
            height: max(0, visibleFrame.height - size.height)
        )
    }

    private static func normalized(
        _ value: CGFloat,
        lowerBound: CGFloat,
        upperBound: CGFloat
    ) -> Double {
        let range = upperBound - lowerBound
        guard range > 0 else {
            return 0
        }
        return clamped(Double((value - lowerBound) / range))
    }

    private static func clamped(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

public struct IndicatorPlacementPreferences: Codable, Equatable, Sendable {
    public var mode: IndicatorPlacementMode
    public private(set) var activeManualDisplayID: String?
    private var placements: [String: IndicatorManualPlacement]

    public init(
        mode: IndicatorPlacementMode = .automatic,
        activeManualDisplayID: String? = nil,
        placements: [String: IndicatorManualPlacement] = [:]
    ) {
        self.mode = mode
        self.activeManualDisplayID = activeManualDisplayID
        self.placements = placements
    }

    public func placement(for displayID: String) -> IndicatorManualPlacement? {
        placements[displayID]
    }

    public mutating func captureManualPlacement(
        frame: CGRect,
        visibleFrame: CGRect,
        displayID: String
    ) {
        placements[displayID] = IndicatorManualPlacement(
            frame: frame,
            in: visibleFrame
        )
        activeManualDisplayID = displayID
    }

    private enum CodingKeys: String, CodingKey {
        case mode
        case activeManualDisplayID
        case placements
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mode = try container.decodeIfPresent(IndicatorPlacementMode.self, forKey: .mode) ?? .automatic
        activeManualDisplayID = try container.decodeIfPresent(String.self, forKey: .activeManualDisplayID)
        placements = try container.decodeIfPresent([String: IndicatorManualPlacement].self, forKey: .placements) ?? [:]
    }
}

public enum IndicatorPlacementResolver {
    public static func frame(
        preferences: IndicatorPlacementPreferences,
        automaticFrame: CGRect,
        displayID: String,
        visibleFrame: CGRect
    ) -> CGRect {
        guard
            preferences.mode.usesManualFrame,
            let placement = preferences.placement(for: displayID)
        else {
            return automaticFrame
        }
        return placement.resolvedFrame(
            in: visibleFrame,
            size: automaticFrame.size
        )
    }
}

public enum IndicatorPointerInteraction {
    public static func beginsDrag(
        mode: IndicatorPlacementMode,
        origin: CGPoint,
        current: CGPoint,
        threshold: CGFloat = 4
    ) -> Bool {
        guard mode == .free else {
            return false
        }
        return hypot(current.x - origin.x, current.y - origin.y) >= threshold
    }
}

/// Tracks a free-position drag across normal AppKit mouse events. Keeping this
/// state independent of the view avoids a nested event loop that starves
/// layout and drawing while the pointer is moving.
public struct IndicatorDragSession: Equatable, Sendable {
    private var origin: CGPoint?
    public private(set) var isDragging = false

    public init() {}

    public mutating func begin(at point: CGPoint) {
        origin = point
        isDragging = false
    }

    public mutating func update(
        to point: CGPoint,
        mode: IndicatorPlacementMode
    ) -> CGPoint? {
        guard let origin else {
            return nil
        }
        if !isDragging {
            guard IndicatorPointerInteraction.beginsDrag(
                mode: mode,
                origin: origin,
                current: point
            ) else {
                return nil
            }
            isDragging = true
        }
        return CGPoint(
            x: point.x - origin.x,
            y: point.y - origin.y
        )
    }

    @discardableResult
    public mutating func end() -> Bool {
        let didDrag = isDragging
        origin = nil
        isDragging = false
        return didDrag
    }
}

/// Resolves a panel attached to the usage indicator without allowing it to
/// cover the indicator. The preferred placement is below and leading-aligned;
/// the resolver moves it above when the lower screen area cannot contain it.
public enum IndicatorAttachedPanelLayout {
    public static func frame(
        indicatorFrame: CGRect,
        panelSize: CGSize,
        visibleFrame: CGRect,
        screenMargin: CGFloat = 8,
        controlGap: CGFloat = 8
    ) -> CGRect {
        let width = min(
            max(0, panelSize.width),
            max(0, visibleFrame.width - screenMargin * 2)
        )
        let maximumPanelHeight = max(0, visibleFrame.height - screenMargin * 2)
        let desiredHeight = min(max(0, panelSize.height), maximumPanelHeight)
        let minimumX = visibleFrame.minX + screenMargin
        let maximumX = visibleFrame.maxX - width - screenMargin
        let leadingX = indicatorFrame.minX
        let trailingX = indicatorFrame.maxX - width
        let x: CGFloat
        if leadingX >= minimumX, leadingX <= maximumX {
            x = leadingX
        } else if trailingX >= minimumX, trailingX <= maximumX {
            x = trailingX
        } else {
            x = min(maximumX, max(minimumX, leadingX))
        }

        let minimumY = visibleFrame.minY + screenMargin
        let maximumY = visibleFrame.maxY - screenMargin
        let belowAvailable = max(0, indicatorFrame.minY - controlGap - minimumY)
        let aboveAvailable = max(0, maximumY - indicatorFrame.maxY - controlGap)
        let placeBelow = belowAvailable >= desiredHeight || aboveAvailable == 0
        let sideAvailableHeight = placeBelow ? belowAvailable : aboveAvailable
        let height = min(desiredHeight, sideAvailableHeight)
        let y = placeBelow
            ? indicatorFrame.minY - controlGap - height
            : indicatorFrame.maxY + controlGap
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

/// Keeps the opening secondary-click from being interpreted as the first
/// outside click that dismisses the position-mode menu.
public struct PositionModeMenuDismissalState: Equatable, Sendable {
    private var isOpening = false

    public init() {}

    public var shouldDismissForOutsidePointerEvent: Bool {
        !isOpening
    }

    public mutating func beginPresentation() {
        isOpening = true
    }

    public mutating func finishOpeningGesture() {
        isOpening = false
    }

    public mutating func reset() {
        isOpening = false
    }
}
