import AppKit
import SidebarCore

@MainActor
final class SidebarStateTracker {
    private enum DefaultsKey {
        static let hostIdentity = "sidebar-state.host-identity"
        static let placement = "sidebar-state.placement"
    }

    private let defaults: UserDefaults
    private var state: SidebarVisibilityState?
    private var processIdentifier: pid_t?
    private var windowFrame: CGRect?
    private var eventMonitors: [Any] = []
    private var onChange: (() -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var placement: OverlayPlacement {
        state?.placement ?? .sidebar
    }

    func start(onChange: @escaping () -> Void) {
        guard eventMonitors.isEmpty else {
            return
        }
        self.onChange = onChange

        if let monitor = NSEvent.addGlobalMonitorForEvents(
            matching: .leftMouseUp,
            handler: { [weak self] _ in
                Task { @MainActor in
                    self?.handleMouseUp()
                }
            }
        ) {
            eventMonitors.append(monitor)
        }
        if let monitor = NSEvent.addGlobalMonitorForEvents(
            matching: .keyDown,
            handler: { [weak self] event in
                Task { @MainActor in
                    self?.handleKeyDown(event)
                }
            }
        ) {
            eventMonitors.append(monitor)
        }
    }

    func stop() {
        for monitor in eventMonitors {
            NSEvent.removeMonitor(monitor)
        }
        eventMonitors.removeAll()
        onChange = nil
    }

    func observeHost(
        identity: String,
        processIdentifier: pid_t,
        windowFrame: CGRect?
    ) {
        self.processIdentifier = processIdentifier
        self.windowFrame = windowFrame

        if var state {
            let previousPlacement = state.placement
            state.observeHost(identity)
            self.state = state
            persist()
            if previousPlacement != state.placement {
                onChange?()
            }
            return
        }

        let restoredPlacement: OverlayPlacement
        if
            let raw = defaults.string(forKey: DefaultsKey.placement),
            let saved = OverlayPlacement(rawValue: raw)
        {
            restoredPlacement = saved
        } else {
            restoredPlacement = .sidebar
        }
        state = SidebarVisibilityState(
            hostIdentity: identity,
            placement: restoredPlacement
        )
        persist()
    }

    @discardableResult
    func observeActualPlacement(_ placement: OverlayPlacement) -> Bool {
        guard var state, state.observePlacement(placement) else {
            return false
        }
        self.state = state
        persist()
        return true
    }

    @discardableResult
    func reloadPersistedPlacement() -> Bool {
        guard
            var state,
            let raw = defaults.string(forKey: DefaultsKey.placement),
            let saved = OverlayPlacement(rawValue: raw),
            state.observePlacement(saved)
        else {
            return false
        }
        self.state = state
        return true
    }

    private func handleMouseUp() {
        guard
            hostIsForeground,
            let windowFrame,
            windowFrame.width >= 560,
            windowFrame.height >= 400
        else {
            return
        }
        let toggleButtonFrame = CGRect(
            x: windowFrame.minX + 80,
            y: windowFrame.maxY - OverlayLayout.toolbarHeight,
            width: 40,
            height: OverlayLayout.toolbarHeight
        )
        guard toggleButtonFrame.contains(NSEvent.mouseLocation) else {
            return
        }
        toggle()
    }

    private func handleKeyDown(_ event: NSEvent) {
        guard hostIsForeground else {
            return
        }
        let relevantModifiers = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .intersection([.command, .shift, .option, .control])
        let isToggle = relevantModifiers == .command
            && event.charactersIgnoringModifiers?.lowercased() == "b"
        guard isToggle else {
            return
        }
        toggle()
    }

    private var hostIsForeground: Bool {
        guard let processIdentifier else {
            return false
        }
        return NSWorkspace.shared.frontmostApplication?.processIdentifier ==
            processIdentifier
    }

    private func toggle() {
        guard var state else {
            return
        }
        state.toggle()
        self.state = state
        persist()
        onChange?()
    }

    private func persist() {
        guard let state else {
            return
        }
        defaults.set(state.hostIdentity, forKey: DefaultsKey.hostIdentity)
        defaults.set(state.placement.rawValue, forKey: DefaultsKey.placement)
        defaults.synchronize()
    }
}
