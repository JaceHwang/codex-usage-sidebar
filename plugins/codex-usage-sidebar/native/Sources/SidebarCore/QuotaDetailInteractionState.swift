public struct QuotaDetailInteractionState: Equatable, Sendable {
    public private(set) var isPinned = false
    private var isPointerInside = false
    private var suppressHoverUntilExit = false

    public init() {}

    public var shouldShowDetail: Bool {
        isPinned || (isPointerInside && !suppressHoverUntilExit)
    }

    public mutating func updatePointerInside(_ inside: Bool) {
        if !inside {
            suppressHoverUntilExit = false
        }
        isPointerInside = inside
    }

    public mutating func togglePinned(pointerInside: Bool) {
        isPointerInside = pointerInside
        if isPinned {
            isPinned = false
            suppressHoverUntilExit = pointerInside
        } else {
            isPinned = true
            suppressHoverUntilExit = false
        }
    }

    public mutating func reset() {
        self = QuotaDetailInteractionState()
    }
}
