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
        let rowHeights = QuotaDetailRowMetrics.heights(
            for: content.rows,
            cardWidth: QuotaDetailLayout.width
        )
        let panelFrame = QuotaDetailLayout.frame(
            indicatorFrame: indicatorFrame,
            rowContentHeight: rowHeights.reduce(0, +),
            visibleFrame: visibleFrame
        )
        let appearance = theme.appKitAppearance
        panel.appearance = appearance
        var card: QuotaDetailCardView?
        appearance.performAsCurrentDrawingAppearance {
            card = QuotaDetailCardView(
                frame: CGRect(origin: .zero, size: panelFrame.size),
                content: content,
                rowHeights: rowHeights
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
    init(
        frame frameRect: NSRect,
        content: QuotaDetailContent,
        rowHeights: [CGFloat]
    ) {
        super.init(frame: frameRect)
        material = .popover
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.masksToBounds = true
        layer?.borderWidth = 0.5
        layer?.borderColor = NSColor.separatorColor
            .withAlphaComponent(0.24).cgColor

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
        let rowDocumentHeight = rowHeights.reduce(0, +)
        let rowDocument = FlippedView(
            frame: CGRect(
                x: 0,
                y: 0,
                width: rowAreaFrame.width,
                height: max(rowAreaFrame.height, rowDocumentHeight)
            )
        )

        var rowY: CGFloat = 0
        for (index, row) in content.rows.enumerated() {
            let rowHeight = rowHeights[index]
            let isStacked = rowHeight > QuotaDetailLayout.rowHeight
            let rowLabel = label(
                row.label,
                font: QuotaDetailRowMetrics.labelFont,
                color: .secondaryLabelColor,
                alignment: .left
            )
            let labelWidth = min(
                108,
                ceil(rowLabel.intrinsicContentSize.width + 2)
            )
            rowLabel.frame = CGRect(
                x: 12,
                y: rowY + 3,
                width: labelWidth,
                height: 18
            )
            rowDocument.addSubview(rowLabel)

            let value = label(
                row.value,
                font: QuotaDetailRowMetrics.valueFont,
                color: .labelColor,
                alignment: .right
            )
            if isStacked {
                let valueHeight = rowHeight - 22
                value.maximumNumberOfLines = Int(valueHeight / 18)
                value.lineBreakMode = .byCharWrapping
                value.frame = CGRect(
                    x: 12,
                    y: rowY + 21,
                    width: bounds.width - 24,
                    height: valueHeight
                )
            } else {
                value.lineBreakMode = .byTruncatingTail
                let valueX = max(68, rowLabel.frame.maxX + 6)
                value.frame = CGRect(
                    x: valueX,
                    y: rowY + 3,
                    width: bounds.width - valueX - 12,
                    height: 18
                )
            }
            rowDocument.addSubview(value)
            rowY += rowHeight
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
private enum QuotaDetailRowMetrics {
    static let labelFont = NSFont.systemFont(ofSize: 12, weight: .regular)
    static let valueFont = NSFont.systemFont(ofSize: 12, weight: .regular)

    static func heights(
        for rows: [QuotaDetailRow],
        cardWidth: CGFloat
    ) -> [CGFloat] {
        rows.map { row in
            let labelWidth = min(108, textWidth(row.label, font: labelFont) + 2)
            let valueX = max(68, 12 + labelWidth + 6)
            let columnWidth = max(1, cardWidth - valueX - 12)
            let measuredValueWidth = textWidth(row.value, font: valueFont)
            guard measuredValueWidth > columnWidth else {
                return QuotaDetailLayout.rowHeight
            }

            let fullWidth = max(1, cardWidth - 24)
            let lineCount = max(1, Int(ceil(measuredValueWidth / fullWidth)))
            return 22 + CGFloat(lineCount) * 18
        }
    }

    private static func textWidth(_ value: String, font: NSFont) -> CGFloat {
        ceil(
            (value as NSString).size(
                withAttributes: [.font: font]
            ).width
        )
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
