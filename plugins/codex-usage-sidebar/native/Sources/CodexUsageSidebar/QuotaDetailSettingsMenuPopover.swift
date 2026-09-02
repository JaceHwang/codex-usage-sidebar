import AppKit
import SidebarCore

@MainActor
final class QuotaDetailSettingsMenuPopover: NSObject {
    private final class PassivePanel: NSPanel {
        override var canBecomeKey: Bool { false }
        override var canBecomeMain: Bool { false }
    }

    private let parentPanel = PassivePanel(
        contentRect: .zero,
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )
    private let submenuPanel = PassivePanel(
        contentRect: .zero,
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )
    private var parentOutsideMonitor: Any?
    private var localOutsideMonitor: Any?
    private var mode: IndicatorPlacementMode = .automatic
    private var localization = QuotaLocalization(language: .english)
    private var theme: CodexInterfaceTheme = .light
    private var onPlacementModeSelected: ((IndicatorPlacementMode) -> Void)?
    private var onCheckForUpdates: (() -> Void)?
    private var onReload: (() -> Void)?
    private var onQuit: (() -> Void)?
    private var submenuDismissWorkItem: DispatchWorkItem?

    var parentFrame: CGRect? {
        parentPanel.isVisible ? parentPanel.frame : nil
    }

    var submenuFrame: CGRect? {
        submenuPanel.isVisible ? submenuPanel.frame : nil
    }

    func contains(_ point: CGPoint) -> Bool {
        parentPanel.frame.contains(point) || submenuPanel.frame.contains(point)
    }

    override init() {
        super.init()
        configure(parentPanel)
        configure(submenuPanel)
    }

    func show(
        relativeTo settingsButtonFrame: CGRect,
        mode: IndicatorPlacementMode,
        localization: QuotaLocalization,
        theme: CodexInterfaceTheme,
        onPlacementModeSelected: @escaping (IndicatorPlacementMode) -> Void,
        onCheckForUpdates: @escaping () -> Void,
        onReload: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.mode = mode
        self.localization = localization
        self.theme = theme
        self.onPlacementModeSelected = onPlacementModeSelected
        self.onCheckForUpdates = onCheckForUpdates
        self.onReload = onReload
        self.onQuit = onQuit

        let frame = QuotaDetailSettingsMenuLayout.parentFrame(
            settingsButtonFrame: settingsButtonFrame
        )
        parentPanel.appearance = theme.appKitAppearance
        parentPanel.setFrame(frame, display: false)
        parentPanel.contentView = parentContentView()
        parentPanel.orderFrontRegardless()
        submenuPanel.orderOut(nil)
        armOutsideMonitorsAfterOpeningGesture()
    }

    func showPositionModeSubmenu() {
        guard parentPanel.isVisible else { return }
        cancelScheduledSubmenuDismissal()
        let frame = QuotaDetailSettingsMenuLayout.submenuFrame(
            parentFrame: parentPanel.frame,
            visibleFrame: visibleScreenFrame(for: parentPanel.frame)
        )
        submenuPanel.appearance = theme.appKitAppearance
        submenuPanel.setFrame(frame, display: false)
        submenuPanel.contentView = submenuContentView()
        submenuPanel.orderFrontRegardless()
    }

    /// Keeps the placement submenu open only while the pointer remains on its
    /// parent row or inside the submenu itself. Exposed at module scope so the
    /// panel lifecycle is covered by the AppKit regression tests.
    func updateSubmenuVisibility(
        isPointerOverPositionMode: Bool,
        isPointerOverSubmenu: Bool
    ) {
        guard !isPointerOverPositionMode, !isPointerOverSubmenu else {
            cancelScheduledSubmenuDismissal()
            return
        }
        cancelScheduledSubmenuDismissal()
        submenuPanel.orderOut(nil)
    }

    func hide() {
        cancelScheduledSubmenuDismissal()
        parentPanel.orderOut(nil)
        submenuPanel.orderOut(nil)
        removeOutsideMonitors()
    }

    private func configure(_ panel: NSPanel) {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    private func visibleScreenFrame(for panelFrame: CGRect) -> CGRect {
        let screen = NSScreen.screens.first { screen in
            screen.visibleFrame.intersects(panelFrame)
        } ?? parentPanel.screen ?? NSScreen.main
        return screen?.visibleFrame ?? panelFrame
    }

    private func parentContentView() -> NSView {
        let view = QuotaCardMaterialView(
            frame: CGRect(origin: .zero, size: QuotaDetailSettingsMenuLayout.parentSize)
        )
        let rowHeight: CGFloat = 40
        let titles = [
            localization.positionModeTitle,
            localization.checkForUpdates,
            localization.reloadCompanion,
            localization.quitCompanion
        ]
        let symbols = ["location", "arrow.down.circle", "arrow.clockwise", "power"]
        for index in titles.indices {
            let button = QuotaDetailSettingsMenuRowButton(
                frame: CGRect(
                    x: 8,
                    y: QuotaDetailSettingsMenuLayout.parentSize.height - CGFloat(index + 1) * rowHeight,
                    width: QuotaDetailSettingsMenuLayout.parentSize.width - 16,
                    height: rowHeight
                ),
                title: titles[index],
                symbolName: symbols[index],
                showsSubmenuChevron: index == 0
            )
            if index == 0 {
                button.onPointerEntered = { [weak self] in
                    self?.showPositionModeSubmenu()
                }
                button.onPointerExited = { [weak self] in
                    self?.scheduleSubmenuDismissal()
                }
                button.onActivate = { [weak self] in
                    self?.showPositionModeSubmenu()
                }
            } else {
                button.onPointerEntered = { [weak self] in
                    self?.hidePositionModeSubmenu()
                }
                button.onActivate = { [weak self] in
                    self?.activateParentAction(at: index)
                }
            }
            view.addSubview(button)
        }
        return view
    }

    private func submenuContentView() -> NSView {
        let view = QuotaCardMaterialView(
            frame: CGRect(origin: .zero, size: QuotaDetailSettingsMenuLayout.submenuSize)
        )
        let rowHeight: CGFloat = 40
        let modes: [IndicatorPlacementMode] = [.automatic, .free, .locked]
        let symbols = ["link", "hand.raised", "lock.fill"]
        for index in modes.indices {
            let placementMode = modes[index]
            let button = QuotaDetailSettingsMenuRowButton(
                frame: CGRect(
                    x: 8,
                    y: QuotaDetailSettingsMenuLayout.submenuSize.height - CGFloat(index + 1) * rowHeight,
                    width: QuotaDetailSettingsMenuLayout.submenuSize.width - 16,
                    height: rowHeight
                ),
                title: localization.settingsPlacementMode(placementMode),
                symbolName: symbols[index],
                showsCheckmark: placementMode == mode
            )
            button.onActivate = { [weak self] in
                guard let self else { return }
                self.onPlacementModeSelected?(placementMode)
                self.hide()
            }
            button.onPointerEntered = { [weak self] in
                self?.cancelScheduledSubmenuDismissal()
            }
            button.onPointerExited = { [weak self] in
                self?.scheduleSubmenuDismissal()
            }
            view.addSubview(button)
        }
        return view
    }

    private func activateParentAction(at index: Int) {
        switch index {
        case 1: onCheckForUpdates?()
        case 2: onReload?()
        case 3: onQuit?()
        default: return
        }
        hide()
    }

    private func hidePositionModeSubmenu() {
        cancelScheduledSubmenuDismissal()
        submenuPanel.orderOut(nil)
    }

    private func scheduleSubmenuDismissal() {
        cancelScheduledSubmenuDismissal()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let pointer = NSEvent.mouseLocation
            self.updateSubmenuVisibility(
                isPointerOverPositionMode: self.positionModeRowFrame.contains(pointer),
                isPointerOverSubmenu: self.submenuPanel.frame.contains(pointer)
            )
        }
        submenuDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: workItem)
    }

    private func cancelScheduledSubmenuDismissal() {
        submenuDismissWorkItem?.cancel()
        submenuDismissWorkItem = nil
    }

    private var positionModeRowFrame: CGRect {
        let rowHeight: CGFloat = 40
        return CGRect(
            x: parentPanel.frame.minX + 8,
            y: parentPanel.frame.maxY - rowHeight,
            width: QuotaDetailSettingsMenuLayout.parentSize.width - 16,
            height: rowHeight
        )
    }

    private func armOutsideMonitorsAfterOpeningGesture() {
        removeOutsideMonitors()
        DispatchQueue.main.async { [weak self] in
            guard let self, self.parentPanel.isVisible else { return }
            self.installOutsideMonitors()
        }
    }

    private func installOutsideMonitors() {
        parentOutsideMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            self?.dismissIfPointerIsOutside()
        }
        localOutsideMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            self?.dismissIfPointerIsOutside()
            return event
        }
    }

    private func dismissIfPointerIsOutside() {
        let point = NSEvent.mouseLocation
        guard !parentPanel.frame.contains(point), !submenuPanel.frame.contains(point) else {
            return
        }
        hide()
    }

    private func removeOutsideMonitors() {
        if let parentOutsideMonitor {
            NSEvent.removeMonitor(parentOutsideMonitor)
        }
        parentOutsideMonitor = nil
        if let localOutsideMonitor {
            NSEvent.removeMonitor(localOutsideMonitor)
        }
        localOutsideMonitor = nil
    }
}

@MainActor
private final class QuotaDetailSettingsMenuRowButton: NSButton {
    var onActivate: (() -> Void)?
    var onPointerEntered: (() -> Void)?
    var onPointerExited: (() -> Void)?
    private let iconView: NSImageView
    private let titleLabel: NSTextField
    private let trailingLabel: NSTextField
    private var trackingArea: NSTrackingArea?
    private var isPointerInside = false

    init(
        frame frameRect: NSRect,
        title: String,
        symbolName: String,
        showsSubmenuChevron: Bool = false,
        showsCheckmark: Bool = false
    ) {
        iconView = NSImageView(
            image: NSImage(systemSymbolName: symbolName, accessibilityDescription: title)
                ?? NSImage(size: NSSize(width: 16, height: 16))
        )
        titleLabel = NSTextField(labelWithString: title)
        trailingLabel = NSTextField(labelWithString: showsCheckmark ? "✓" : (showsSubmenuChevron ? "›" : ""))
        super.init(frame: frameRect)
        self.title = ""
        isBordered = false
        setButtonType(.momentaryPushIn)
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.cornerCurve = .continuous
        target = self
        action = #selector(activate)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.image?.isTemplate = true
        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = .labelColor
        trailingLabel.font = .systemFont(ofSize: 14, weight: .medium)
        trailingLabel.textColor = .secondaryLabelColor
        trailingLabel.alignment = .right
        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(trailingLabel)
        updateAppearance()
    }

    override func layout() {
        super.layout()
        iconView.frame = CGRect(x: 10, y: 12, width: 16, height: 16)
        titleLabel.frame = CGRect(x: 34, y: 10, width: bounds.width - 64, height: 18)
        trailingLabel.frame = CGRect(x: bounds.width - 24, y: 9, width: 14, height: 20)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isPointerInside = true
        updateAppearance()
        onPointerEntered?()
    }

    override func mouseExited(with event: NSEvent) {
        isPointerInside = false
        updateAppearance()
        onPointerExited?()
    }

    @objc private func activate() {
        onActivate?()
    }

    private func updateAppearance() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = NSColor.labelColor
                .withAlphaComponent(isPointerInside ? 0.10 : 0)
                .cgColor
            iconView.contentTintColor = .secondaryLabelColor
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }
}
