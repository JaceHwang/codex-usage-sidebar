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
    private let pillView = NSView()
    private let detailPanel = QuotaDetailPanel()
    private var hoverTimer: Timer?
    private var latestDetail: QuotaDetailContent?
    private var latestPlacement: OverlayPlacement = .sidebar
    private var latestTheme: CodexInterfaceTheme = .light
    private var isIndicatorVisible = false
    private var isHoveringIndicator = false

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
        contentView.addSubview(pillView)
        contentView.addSubview(textField)
    }

    func show(
        snapshot: AllowanceSnapshot,
        label: String,
        indicatorFrame: CGRect,
        placement: OverlayPlacement,
        theme: CodexInterfaceTheme,
        detail: QuotaDetailContent,
        dimmed: Bool
    ) {
        let appearance = theme.appKitAppearance
        panel.appearance = appearance
        panel.contentView?.appearance = appearance
        pillView.appearance = appearance
        textField.appearance = appearance
        appearance.performAsCurrentDrawingAppearance {
            textField.attributedStringValue = attributedLabel(
                label,
                remainingPercent: snapshot.remainingPercent,
                alignment: .center
            )
        }
        latestDetail = detail
        latestPlacement = placement
        latestTheme = theme
        isIndicatorVisible = true
        panel.alphaValue = dimmed ? 0.52 : 1
        panel.setFrame(indicatorFrame, display: true)
        let indicatorBounds = CGRect(origin: .zero, size: indicatorFrame.size)
        let controlSurface = OverlayLayout.controlSurfaceFrame(in: indicatorBounds)
        pillView.isHidden = false
        pillView.frame = controlSurface
        textField.frame = OverlayLayout.centeredTextFrame(
            in: controlSurface,
            intrinsicHeight: textField.intrinsicContentSize.height,
            horizontalInset: 8
        )
        updateControlAppearance()
        panel.orderFrontRegardless()
        startHoverTimerIfNeeded()
    }

    func hide() {
        isIndicatorVisible = false
        isHoveringIndicator = false
        panel.orderOut(nil)
        detailPanel.hide()
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
                .font: NSFont.systemFont(ofSize: 10, weight: .regular),
                .foregroundColor: NSColor.tertiaryLabelColor,
                .paragraphStyle: paragraph
            ],
            range: fullRange
        )

        if let percentRange = label.range(of: "\(remainingPercent)%") {
            let range = NSRange(percentRange, in: label)
            result.addAttributes(
                [
                    .font: NSFont.systemFont(ofSize: 11, weight: .medium),
                    .foregroundColor: remainingPercent <= 10
                        ? NSColor.systemRed
                        : NSColor.secondaryLabelColor
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
            let latestDetail
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
        if overIndicator || overDetail || overBridge {
            detailPanel.show(
                content: latestDetail,
                relativeTo: panel.frame,
                placement: latestPlacement,
                theme: latestTheme
            )
        } else {
            detailPanel.hide()
        }
    }

    private func updateControlAppearance() {
        let appearance = latestTheme.appKitAppearance
        appearance.performAsCurrentDrawingAppearance {
            switch OverlaySurfacePolicy.treatment(
                isIndicatorHovered: isHoveringIndicator
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
