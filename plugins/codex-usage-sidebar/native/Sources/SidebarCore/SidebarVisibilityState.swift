import Foundation

public struct SidebarVisibilityState: Equatable, Sendable {
    public private(set) var hostIdentity: String
    public private(set) var placement: OverlayPlacement

    public init(
        hostIdentity: String,
        placement _: OverlayPlacement = .titlebar
    ) {
        self.hostIdentity = hostIdentity
        self.placement = .titlebar
    }

    public mutating func observeHost(_ identity: String) {
        guard identity != hostIdentity else {
            return
        }
        hostIdentity = identity
    }

    public mutating func toggle() {
        placement = .titlebar
    }

    @discardableResult
    public mutating func observePlacement(
        _: OverlayPlacement
    ) -> Bool {
        let changed = placement != .titlebar
        placement = .titlebar
        return changed
    }
}
