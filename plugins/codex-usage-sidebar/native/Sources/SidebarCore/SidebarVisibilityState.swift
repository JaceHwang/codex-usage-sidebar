import Foundation

public struct SidebarVisibilityState: Equatable, Sendable {
    public private(set) var hostIdentity: String
    public private(set) var placement: OverlayPlacement

    public init(
        hostIdentity: String,
        placement: OverlayPlacement = .sidebar
    ) {
        self.hostIdentity = hostIdentity
        self.placement = placement
    }

    public mutating func observeHost(_ identity: String) {
        guard identity != hostIdentity else {
            return
        }
        hostIdentity = identity
    }

    public mutating func toggle() {
        placement = placement == .sidebar ? .titlebar : .sidebar
    }

    @discardableResult
    public mutating func observePlacement(
        _ observedPlacement: OverlayPlacement
    ) -> Bool {
        guard observedPlacement != placement else {
            return false
        }
        placement = observedPlacement
        return true
    }
}
