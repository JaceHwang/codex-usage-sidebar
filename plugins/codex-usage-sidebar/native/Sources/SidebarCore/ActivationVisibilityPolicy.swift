public enum ActivationVisibilityDecision: Equatable, Sendable {
    case reconcileHost
    case preserve
    case hide
}

public enum ActivationVisibilityPolicy {
    public static func decision(
        activatedBundleIdentifier: String?,
        hostBundleIdentifier: String,
        companionBundleIdentifier: String?
    ) -> ActivationVisibilityDecision {
        if activatedBundleIdentifier == hostBundleIdentifier {
            return .reconcileHost
        }
        if
            let companionBundleIdentifier,
            activatedBundleIdentifier == companionBundleIdentifier
        {
            return .preserve
        }
        return .hide
    }
}
