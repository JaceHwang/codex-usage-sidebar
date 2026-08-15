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
    var onOpenURL: ((URL) -> Void)?

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
            cardWidth: QuotaDetailLayout.width,
            remainingPercent: content.remainingPercent
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
                rowHeights: rowHeights,
                onOpenURL: { [weak self] destination in
                    self?.onOpenURL?(destination)
                }
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
private final class QuotaDetailCardView: NSView {
    init(
        frame frameRect: NSRect,
        content: QuotaDetailContent,
        rowHeights: [CGFloat],
        onOpenURL: @escaping (URL) -> Void
    ) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        layer?.borderWidth = 0.5
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        layer?.borderColor = NSColor.separatorColor.cgColor

        let title = label(
            content.title,
            font: .systemFont(ofSize: 13, weight: .semibold),
            color: .labelColor,
            alignment: .left
        )
        title.lineBreakMode = .byTruncatingTail

        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "dev"
        let versionBadge = VersionBadgeView(text: "v\(version)")

        let remaining = label(
            "\(content.remainingPercent)%",
            font: .systemFont(ofSize: 17, weight: .semibold),
            color: QuotaColorScale.components(
                remainingPercent: content.remainingPercent
            ).appKitColor,
            alignment: .right
        )
        let headerFrames = QuotaDetailLayout.headerFrames(
            in: bounds,
            titleWidth: QuotaDetailLayout.titleWidth(
                intrinsicWidth: title.intrinsicContentSize.width,
                fittingWidth: title.fittingSize.width
            ),
            versionBadgeWidth: versionBadge.intrinsicContentSize.width
        )
        title.frame = headerFrames.title
        versionBadge.frame = headerFrames.versionBadge
        remaining.frame = headerFrames.remaining
        addSubview(title)
        addSubview(versionBadge)
        addSubview(remaining)

        let progress = QuotaProgressView(
            frame: CGRect(x: 12, y: bounds.height - 50, width: bounds.width - 24, height: 4),
            value: content.remainingPercent
        )
        addSubview(progress)

        let informationFrames = QuotaDetailLayout.informationFrames(in: bounds)
        let topDivider = NSBox(
            frame: informationFrames.topDivider
        )
        topDivider.boxType = .separator
        addSubview(topDivider)

        let informationLink = QuotaInformationLinkButton(
            frame: informationFrames.control,
            entry: content.informationEntry,
            onActivate: onOpenURL
        )
        addSubview(informationLink)

        let bottomDivider = NSBox(
            frame: informationFrames.bottomDivider
        )
        bottomDivider.boxType = .separator
        addSubview(bottomDivider)

        let rowAreaFrame = informationFrames.rowArea
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
            value.attributedStringValue = QuotaCountdownTypography.string(
                row.value,
                remainingPercent: content.remainingPercent
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
private final class VersionBadgeView: NSView {
    private let text: String
    private let font = NSFont.systemFont(
        ofSize: 8,
        weight: .medium
    )

    init(text: String) {
        self.text = text
        super.init(frame: .zero)
    }

    override var intrinsicContentSize: NSSize {
        let textSize = (text as NSString).size(
            withAttributes: [.font: font]
        )
        return NSSize(width: ceil(textSize.width) + 10, height: 14)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let capsuleBounds = bounds.insetBy(dx: 0.5, dy: 0.5)
        let capsule = NSBezierPath(
            roundedRect: capsuleBounds,
            xRadius: capsuleBounds.height / 2,
            yRadius: capsuleBounds.height / 2
        )
        NSColor.systemBlue.withAlphaComponent(0.52).setStroke()
        capsule.lineWidth = 0.75
        capsule.stroke()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.systemBlue
        ]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let textPoint = CGPoint(
            x: floor((bounds.width - textSize.width) / 2),
            y: floor((bounds.height - textSize.height) / 2)
        )
        (text as NSString).draw(at: textPoint, withAttributes: attributes)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }
}

@MainActor
private enum QuotaDetailRowMetrics {
    static let labelFont = NSFont.systemFont(ofSize: 12, weight: .regular)
    static let valueFont = NSFont.systemFont(ofSize: 12, weight: .regular)

    static func heights(
        for rows: [QuotaDetailRow],
        cardWidth: CGFloat,
        remainingPercent: Int
    ) -> [CGFloat] {
        rows.map { row in
            let labelWidth = min(108, textWidth(row.label, font: labelFont) + 2)
            let valueX = max(68, 12 + labelWidth + 6)
            let columnWidth = max(1, cardWidth - valueX - 12)
            let measuredValueWidth = ceil(
                QuotaCountdownTypography.string(
                    row.value,
                    remainingPercent: remainingPercent
                ).size().width
            )
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
private enum QuotaCountdownTypography {
    private static let digitFont = NSFont.systemFont(
        ofSize: 14,
        weight: .semibold
    )
    private static let unitFont = NSFont.systemFont(
        ofSize: 10,
        weight: .medium
    )
    private static let punctuationFont = NSFont.systemFont(
        ofSize: 10,
        weight: .regular
    )

    static func string(
        _ value: String,
        remainingPercent: Int
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let accentColor = QuotaColorScale.components(
            remainingPercent: remainingPercent
        ).appKitColor

        for segment in QuotaCountdownSegmenter.segments(in: value) {
            let attributes: [NSAttributedString.Key: Any]
            switch segment.role {
            case .plain:
                attributes = [
                    .font: QuotaDetailRowMetrics.valueFont,
                    .foregroundColor: NSColor.labelColor
                ]
            case .digits:
                attributes = [
                    .font: digitFont,
                    .foregroundColor: accentColor
                ]
            case .unit:
                attributes = [
                    .font: unitFont,
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
            case .punctuation, .suffix:
                attributes = [
                    .font: punctuationFont,
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
            }
            result.append(
                NSAttributedString(
                    string: segment.text,
                    attributes: attributes
                )
            )
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right
        result.addAttribute(
            .paragraphStyle,
            value: paragraph,
            range: NSRange(location: 0, length: result.length)
        )
        return result
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
        let stops = QuotaColorScale.progressGradientStops
        let colors = stops.map(\.components.appKitColor)
        let locations = stops.map { CGFloat($0.location) }
        let gradient = locations.withUnsafeBufferPointer {
            NSGradient(
                colors: colors,
                atLocations: $0.baseAddress,
                colorSpace: .deviceRGB
            )
        }
        NSGraphicsContext.saveGraphicsState()
        fill.addClip()
        gradient?.draw(in: bounds, angle: 0)
        NSGraphicsContext.restoreGraphicsState()
    }
}
