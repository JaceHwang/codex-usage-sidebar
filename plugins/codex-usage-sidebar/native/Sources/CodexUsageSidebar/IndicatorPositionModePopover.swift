import AppKit
import SidebarCore

@MainActor
final class IndicatorPositionModePopover: NSObject {
    private final class PassivePanel: NSPanel {
        override var canBecomeKey: Bool { false }
        override var canBecomeMain: Bool { false }
    }

    private let panel = PassivePanel(
        contentRect: .zero,
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )
    private let contentView = QuotaCardMaterialView(frame: .zero)
    private let titleField = NSTextField(labelWithString: "")
    private let separator = NSBox()
    private let segmented = NSSegmentedControl(
        labels: ["", "", ""],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let descriptionField = NSTextField(labelWithString: "")
    private var selectedMode: IndicatorPlacementMode = .automatic
    private var onSelection: ((IndicatorPlacementMode) -> Void)?
    private var outsideMonitor: Any?
    private var dismissalState = PositionModeMenuDismissalState()

    var isVisible: Bool {
        panel.isVisible
    }

    var frame: CGRect? {
        panel.isVisible ? panel.frame : nil
    }

    override init() {
        super.init()
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = contentView
        titleField.font = .systemFont(ofSize: 12, weight: .semibold)
        descriptionField.font = .systemFont(ofSize: 11, weight: .regular)
        descriptionField.textColor = .secondaryLabelColor
        separator.boxType = .separator
        segmented.target = self
        segmented.action = #selector(selectMode(_:))
        contentView.addSubview(titleField)
        contentView.addSubview(segmented)
        contentView.addSubview(separator)
        contentView.addSubview(descriptionField)
    }

    func show(
        relativeTo indicatorFrame: CGRect,
        mode: IndicatorPlacementMode,
        localization: QuotaLocalization,
        theme: CodexInterfaceTheme,
        onSelection: @escaping (IndicatorPlacementMode) -> Void
    ) {
        self.selectedMode = mode
        self.onSelection = onSelection
        dismissalState.beginPresentation()
        let appearance = theme.appKitAppearance
        panel.appearance = appearance
        panel.contentView?.appearance = appearance
        titleField.stringValue = localization.positionModeTitle
        segmented.setLabel(localization.indicatorPlacementMode(.automatic), forSegment: 0)
        segmented.setLabel(localization.indicatorPlacementMode(.free), forSegment: 1)
        segmented.setLabel(localization.indicatorPlacementMode(.locked), forSegment: 2)
        segmented.selectedSegment = mode.segmentIndex
        segmented.setAccessibilityLabel(localization.positionModeTitle)
        descriptionField.stringValue = localization.indicatorPlacementDescription(mode)
        panel.setFrame(resolvedFrame(relativeTo: indicatorFrame), display: true)
        layoutSubviews()
        panel.orderFrontRegardless()
        // The opening right-click can be observed by a global monitor for a
        // non-activating helper panel. Arm the monitor only after that event
        // has completed, otherwise the menu immediately dismisses itself.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.panel.isVisible else { return }
            self.dismissalState.finishOpeningGesture()
            self.installOutsideMonitor()
        }
    }

    func hide() {
        dismissalState.reset()
        panel.orderOut(nil)
        removeOutsideMonitor()
    }

    func reposition(relativeTo indicatorFrame: CGRect) {
        guard panel.isVisible else { return }
        let frame = resolvedFrame(relativeTo: indicatorFrame)
        guard panel.frame != frame else { return }
        panel.setFrame(frame, display: true)
        layoutSubviews()
    }

    private func resolvedFrame(relativeTo indicatorFrame: CGRect) -> CGRect {
        let screen = NSScreen.screens.first {
            $0.frame.contains(
                CGPoint(x: indicatorFrame.midX, y: indicatorFrame.midY)
            )
        } ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? indicatorFrame.insetBy(
            dx: -130,
            dy: -59
        )
        return IndicatorAttachedPanelLayout.frame(
            indicatorFrame: indicatorFrame,
            panelSize: CGSize(width: 260, height: 118),
            visibleFrame: visibleFrame
        )
    }

    private func layoutSubviews() {
        guard let view = panel.contentView else { return }
        titleField.frame = CGRect(x: 16, y: 86, width: 228, height: 18)
        segmented.frame = CGRect(x: 16, y: 48, width: 228, height: 30)
        separator.frame = CGRect(x: 16, y: 38, width: 228, height: 1)
        descriptionField.frame = CGRect(x: 16, y: 14, width: 228, height: 18)
        view.layoutSubtreeIfNeeded()
    }

    @objc
    private func selectMode(_ sender: NSSegmentedControl) {
        let mode = IndicatorPlacementMode(segmentIndex: sender.selectedSegment)
        selectedMode = mode
        onSelection?(mode)
        hide()
    }

    private func installOutsideMonitor() {
        removeOutsideMonitor()
        outsideMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            guard let self,
                  self.dismissalState.shouldDismissForOutsidePointerEvent
            else {
                return
            }
            self.hide()
        }
    }

    private func removeOutsideMonitor() {
        if let outsideMonitor {
            NSEvent.removeMonitor(outsideMonitor)
        }
        outsideMonitor = nil
    }
}

private extension IndicatorPlacementMode {
    var segmentIndex: Int {
        switch self {
        case .automatic: 0
        case .free: 1
        case .locked: 2
        }
    }

    init(segmentIndex: Int) {
        switch segmentIndex {
        case 1: self = .free
        case 2: self = .locked
        default: self = .automatic
        }
    }
}
