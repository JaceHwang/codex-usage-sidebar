import AppKit
import CoreGraphics
import SidebarCore

@MainActor
extension CodexInterfaceTheme {
    var appKitAppearance: NSAppearance {
        if let appearance = NSAppearance(
            named: self == .dark ? .darkAqua : .aqua
        ) {
            return appearance
        }
        return NSApplication.shared.effectiveAppearance
    }
}

@MainActor
final class OverlayPanel: NSObject {
    private final class PassivePanel: NSPanel {
        override var canBecomeKey: Bool { false }
        override var canBecomeMain: Bool { false }
    }

    private let panel: NSPanel
    private let textField: NSTextField
    private let indicatorIconView = QuotaThemeIconView(frame: .zero)
    private let pillView = NSView()
    private let detailPanel = QuotaDetailPanel()
    private var hoverTimer: Timer?
    private var latestDetail: QuotaDetailContent?
    private var latestTheme: CodexInterfaceTheme = .light
    private var isIndicatorVisible = false
    private var isHoveringIndicator = false
    private var detailInteraction = QuotaDetailInteractionState()
    private lazy var externalLinkActivator = QuotaExternalLinkActivator(
        dismiss: { [weak self] in
            self?.dismissDetailForExternalNavigation()
        },
        open: { destination in
            NSWorkspace.shared.open(destination)
        }
    )

    override init() {
        panel = PassivePanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        textField = NSTextField(labelWithString: "")
        super.init()

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSView(frame: .zero)

        pillView.wantsLayer = true
        pillView.layer?.cornerRadius = 10
        pillView.layer?.borderWidth = 0
        indicatorIconView.wantsLayer = true
        textField.isBezeled = false
        textField.drawsBackground = false
        textField.isEditable = false
        textField.isSelectable = false
        textField.lineBreakMode = .byClipping
        textField.maximumNumberOfLines = 1
        textField.alignment = .right

        guard let contentView = panel.contentView else {
            return
        }
        detailPanel.onOpenURL = { [weak self] destination in
            self?.externalLinkActivator.activate(destination)
        }
        pillView.addSubview(indicatorIconView)
        contentView.addSubview(pillView)
        contentView.addSubview(textField)
        contentView.addGestureRecognizer(
            NSClickGestureRecognizer(
                target: self,
                action: #selector(toggleDetailPin(_:))
            )
        )
    }

    func show(
        snapshot: AllowanceSnapshot,
        label: String,
        indicatorFrame: CGRect,
        theme: CodexInterfaceTheme,
        detail: QuotaDetailContent,
        dimmed: Bool
    ) {
        let appearance = theme.appKitAppearance
        panel.appearance = appearance
        panel.contentView?.appearance = appearance
        pillView.appearance = appearance
        indicatorIconView.updateAppearance(appearance)
        textField.appearance = appearance
        appearance.performAsCurrentDrawingAppearance {
            textField.attributedStringValue = attributedLabel(
                label,
                remainingPercent: snapshot.remainingPercent,
                alignment: .center
            )
        }
        latestDetail = detail
        latestTheme = theme
        isIndicatorVisible = true
        panel.alphaValue = dimmed ? 0.52 : 1
        panel.setFrame(indicatorFrame, display: true)
        let indicatorBounds = CGRect(origin: .zero, size: indicatorFrame.size)
        let controlSurface = OverlayLayout.controlSurfaceFrame(in: indicatorBounds)
        pillView.isHidden = false
        pillView.frame = controlSurface
        let iconSize = min(20, max(0, controlSurface.height - 8))
        indicatorIconView.frame = CGRect(
            x: 6,
            y: floor((controlSurface.height - iconSize) / 2),
            width: iconSize,
            height: iconSize
        )
        let textHeight = max(
            0,
            min(textField.intrinsicContentSize.height, controlSurface.height)
        )
        textField.frame = CGRect(
            x: controlSurface.minX + iconSize + 12,
            y: controlSurface.minY + floor((controlSurface.height - textHeight) / 2),
            width: max(0, controlSurface.width - iconSize - 20),
            height: textHeight
        )
        updateControlAppearance()
        panel.orderFrontRegardless()
        updateDetailVisibility()
        startHoverTimerIfNeeded()
    }

    func preferredIndicatorWidth(label: String, remainingPercent: Int) -> CGFloat {
        let measuredLabel = attributedLabel(
            label,
            remainingPercent: remainingPercent,
            alignment: .left
        ).size().width
        return OverlayLayout.indicatorWidth(for: measuredLabel)
    }

    func hide() {
        isIndicatorVisible = false
        isHoveringIndicator = false
        detailInteraction.reset()
        panel.orderOut(nil)
        detailPanel.hide()
    }

    func reposition(to frame: CGRect) {
        guard isIndicatorVisible else {
            return
        }
        if panel.frame != frame {
            panel.setFrame(frame, display: true)
        }
        // Codex can rebuild/reorder its title-bar views while a side pane is
        // being resized. Reassert the non-activating panel's z-order so the
        // fallback indicator cannot be covered by the host window.
        panel.orderFrontRegardless()
    }

    private func attributedLabel(
        _ label: String,
        remainingPercent: Int,
        alignment: NSTextAlignment
    ) -> NSAttributedString {
        let result = NSMutableAttributedString(string: label)
        let fullRange = NSRange(location: 0, length: result.length)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byClipping
        result.addAttributes(
            [
                .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraph
            ],
            range: fullRange
        )

        if let percentRange = label.range(of: "\(remainingPercent)%") {
            let range = NSRange(percentRange, in: label)
            result.addAttributes(
                [
                    .font: NSFont.systemFont(ofSize: 14, weight: .bold),
                    .foregroundColor: QuotaColorScale.components(
                        remainingPercent: remainingPercent
                    ).appKitColor
                ],
                range: range
            )
        }
        return result
    }

    private func startHoverTimerIfNeeded() {
        guard hoverTimer == nil else {
            return
        }
        let timer = Timer(
            timeInterval: 0.1,
            target: self,
            selector: #selector(pollHover),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        hoverTimer = timer
    }

    @objc
    private func pollHover() {
        guard
            isIndicatorVisible,
            latestDetail != nil
        else {
            detailPanel.hide()
            return
        }
        let point = NSEvent.mouseLocation
        let overIndicator = panel.frame.contains(point)
        let detailFrame = detailPanel.frame
        let overDetail = detailFrame?.contains(point) == true
        let overBridge = detailFrame.map {
            QuotaDetailLayout.hoverBridgeFrame(
                indicatorFrame: panel.frame,
                detailFrame: $0
            ).contains(point)
        } ?? false
        if isHoveringIndicator != overIndicator {
            isHoveringIndicator = overIndicator
            updateControlAppearance()
        }
        detailInteraction.updatePointerInside(
            overIndicator || overDetail || overBridge
        )
        updateDetailVisibility()
    }

    @objc
    private func toggleDetailPin(_ gesture: NSClickGestureRecognizer) {
        guard
            gesture.state == .ended,
            isIndicatorVisible,
            latestDetail != nil
        else {
            return
        }
        detailInteraction.togglePinned(
            pointerInside: panel.frame.contains(NSEvent.mouseLocation)
        )
        updateControlAppearance()
        updateDetailVisibility()
    }

    private func updateDetailVisibility() {
        if
            isIndicatorVisible,
            detailInteraction.shouldShowDetail,
            let latestDetail
        {
            detailPanel.show(
                content: latestDetail,
                relativeTo: panel.frame,
                theme: latestTheme
            )
        } else {
            detailPanel.hide()
        }
    }

    private func dismissDetailForExternalNavigation() {
        detailInteraction.reset()
        isHoveringIndicator = false
        detailPanel.hide()
        updateControlAppearance()
    }

    private func updateControlAppearance() {
        let appearance = latestTheme.appKitAppearance
        appearance.performAsCurrentDrawingAppearance {
            switch OverlaySurfacePolicy.treatment(
                isIndicatorHovered: isHoveringIndicator ||
                    detailInteraction.isPinned
            ) {
            case .hostBackground:
                pillView.layer?.backgroundColor = NSColor.clear.cgColor
            case .quotaHover:
                pillView.layer?.backgroundColor = NSColor.labelColor
                    .withAlphaComponent(0.07)
                    .cgColor
            }
        }
    }
}
