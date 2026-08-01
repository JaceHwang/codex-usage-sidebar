public enum OverlaySurfaceTreatment: Equatable, Sendable {
    case hostBackground
    case quotaHover
}

public enum OverlaySurfacePolicy {
    public static func treatment(
        isIndicatorHovered: Bool
    ) -> OverlaySurfaceTreatment {
        isIndicatorHovered ? .quotaHover : .hostBackground
    }
}
