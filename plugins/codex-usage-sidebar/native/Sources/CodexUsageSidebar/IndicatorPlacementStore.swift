import AppKit
import SidebarCore

@MainActor
final class IndicatorPlacementStore {
    private let defaults: UserDefaults
    private let key: String

    init(
        defaults: UserDefaults = .standard,
        key: String = "com.jace.codex-usage-sidebar.indicator-placement.v1"
    ) {
        self.defaults = defaults
        self.key = key
    }

    var preferences: IndicatorPlacementPreferences {
        get {
            guard
                let data = defaults.data(forKey: key),
                let value = try? JSONDecoder().decode(
                    IndicatorPlacementPreferences.self,
                    from: data
                )
            else {
                return IndicatorPlacementPreferences()
            }
            return value
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else {
                return
            }
            defaults.set(data, forKey: key)
        }
    }

    func screen(containing frame: CGRect) -> NSScreen? {
        NSScreen.screens.first {
            $0.visibleFrame.intersects(frame) &&
                $0.frame.contains(CGPoint(x: frame.midX, y: frame.midY))
        } ?? NSScreen.main
    }

    func displayID(for screen: NSScreen) -> String {
        let number = screen.deviceDescription[
            NSDeviceDescriptionKey("NSScreenNumber")
        ] as? NSNumber
        return "display-\(number?.uint32Value ?? 0)"
    }

    func screen(forDisplayID displayID: String) -> NSScreen? {
        NSScreen.screens.first { self.displayID(for: $0) == displayID }
    }
}
