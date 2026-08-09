import AppKit
import SidebarCore

@MainActor
final class QuotaDetailPanel {
    private final class PassivePanel: NSPanel {
        override var canBecomeKey: Bool { false }
        override var canBecomeMain: Bool { false }
    }

    private let panel: NSPanel
    private var lastContent: QuotaDetailContent?
    private var lastIndicatorFrame: CGRect?
    private var lastTheme: CodexInterfaceTheme?

    init() {
        panel = PassivePanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.hidesOnDeactivate = false
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    var frame: CGRect? {
        panel.isVisible ? panel.frame : nil
    }

    func show(
        content: QuotaDetailContent,
        relativeTo indicatorFrame: CGRect,
        theme: CodexInterfaceTheme
    ) {
        if
            panel.isVisible,
            lastContent == content,
            lastIndicatorFrame == indicatorFrame,
            lastTheme == theme
        {
            return
        }
        lastContent = content
        lastIndicatorFrame = indicatorFrame
        lastTheme = theme

        let screen = NSScreen.screens.first {
            $0.frame.contains(
                CGPoint(x: indicatorFrame.midX, y: indicatorFrame.midY)
            )
        } ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? indicatorFrame.insetBy(
            dx: -400,
            dy: -400
        )
        let panelFrame = QuotaDetailLayout.frame(
            indicatorFrame: indicatorFrame,
            rowCount: content.rows.count,
            visibleFrame: visibleFrame
        )
        let appearance = theme.appKitAppearance
        panel.appearance = appearance
        var card: QuotaDetailCardView?
        appearance.performAsCurrentDrawingAppearance {
            card = QuotaDetailCardView(
                frame: CGRect(origin: .zero, size: panelFrame.size),
                content: content
            )
            card?.appearance = appearance
        }
        panel.contentView = card
        panel.setFrame(panelFrame, display: true)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }
}

@MainActor
private final class QuotaDetailCardView: NSVisualEffectView {
    init(frame frameRect: NSRect, content: QuotaDetailContent) {
        super.init(frame: frameRect)
        material = .menu
        blendingMode = .withinWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = 11
        layer?.masksToBounds = true
        layer?.borderWidth = 0.5
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.48).cgColor

        let title = label(
            content.title,
            font: .systemFont(ofSize: 13, weight: .semibold),
            color: .labelColor,
            alignment: .left
        )
        title.frame = CGRect(x: 12, y: bounds.height - 35, width: 132, height: 20)
        addSubview(title)

        let remaining = label(
            "\(content.remainingPercent)%",
            font: .systemFont(ofSize: 17, weight: .semibold),
            color: QuotaColorScale.components(
                remainingPercent: content.remainingPercent
            ).appKitColor,
            alignment: .right
        )
        remaining.frame = CGRect(
            x: bounds.width - 67,
            y: bounds.height - 37,
            width: 55,
            height: 22
        )
        addSubview(remaining)

        let progress = QuotaProgressView(
            frame: CGRect(x: 12, y: bounds.height - 50, width: bounds.width - 24, height: 4),
            value: content.remainingPercent
        )
        addSubview(progress)

        let divider = NSBox(
            frame: CGRect(x: 0, y: bounds.height - 66, width: bounds.width, height: 1)
        )
        divider.boxType = .separator
        addSubview(divider)

        let rowAreaFrame = CGRect(
            x: 0,
            y: 8,
            width: bounds.width,
            height: max(0, bounds.height - QuotaDetailLayout.headerHeight - 8)
        )
        let rowDocumentHeight = CGFloat(content.rows.count) *
            QuotaDetailLayout.rowHeight
        let rowDocument = FlippedView(
            frame: CGRect(
                x: 0,
                y: 0,
                width: rowAreaFrame.width,
                height: max(rowAreaFrame.height, rowDocumentHeight)
            )
        )

        for (index, row) in content.rows.enumerated() {
            let y = CGFloat(index) * QuotaDetailLayout.rowHeight + 3
            let rowLabel = label(
                row.label,
                font: .systemFont(ofSize: 12, weight: .regular),
                color: .secondaryLabelColor,
                alignment: .left
            )
            let labelWidth = min(
                108,
                ceil(rowLabel.intrinsicContentSize.width + 2)
            )
            rowLabel.frame = CGRect(x: 12, y: y, width: labelWidth, height: 18)
            rowDocument.addSubview(rowLabel)

            let value = label(
                row.value,
                font: .systemFont(ofSize: 12, weight: .regular),
                color: .labelColor,
                alignment: .right
            )
            value.lineBreakMode = .byTruncatingTail
            let valueX = max(82, rowLabel.frame.maxX + 6)
            value.frame = CGRect(
                x: valueX,
                y: y,
                width: bounds.width - valueX - 12,
                height: 18
            )
            rowDocument.addSubview(value)
        }

        let scrollView = NSScrollView(frame: rowAreaFrame)
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = rowDocumentHeight > rowAreaFrame.height
        scrollView.autohidesScrollers = true
        scrollView.documentView = rowDocument
        addSubview(scrollView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    private func label(
        _ value: String,
        font: NSFont,
        color: NSColor,
        alignment: NSTextAlignment
    ) -> NSTextField {
        let field = NSTextField(labelWithString: value)
        field.font = font
        field.textColor = color
        field.alignment = alignment
        field.maximumNumberOfLines = 1
        field.isSelectable = false
        return field
    }
}

@MainActor
private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

@MainActor
private final class QuotaProgressView: NSView {
    private let value: Int

    init(frame frameRect: NSRect, value: Int) {
        self.value = min(100, max(0, value))
        super.init(frame: frameRect)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let track = NSBezierPath(roundedRect: bounds, xRadius: 2.5, yRadius: 2.5)
        NSColor.quaternaryLabelColor.setFill()
        track.fill()

        let fraction = CGFloat(value) / 100
        let fillRect = CGRect(
            x: bounds.minX,
            y: bounds.minY,
            width: max(bounds.height, bounds.width * fraction),
            height: bounds.height
        )
        let fill = NSBezierPath(roundedRect: fillRect, xRadius: 2.5, yRadius: 2.5)
        QuotaColorScale.components(
            remainingPercent: value
        ).appKitColor.setFill()
        fill.fill()
    }
}
