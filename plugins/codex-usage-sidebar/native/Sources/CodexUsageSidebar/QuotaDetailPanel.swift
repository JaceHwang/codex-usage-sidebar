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
        let resolvedLayout = QuotaDetailPanelResolvedLayout.resolve(
            content: content,
            indicatorFrame: indicatorFrame,
            visibleFrame: visibleFrame
        )
        let rowHeights = resolvedLayout.rowHeights
        let panelFrame = resolvedLayout.frame
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
struct QuotaDetailPanelResolvedLayout {
    let frame: CGRect
    let rowHeights: [CGFloat]

    static func resolve(
        content: QuotaDetailContent,
        indicatorFrame: CGRect,
        visibleFrame: CGRect
    ) -> QuotaDetailPanelResolvedLayout {
        let widthFrame = QuotaDetailLayout.frame(
            indicatorFrame: indicatorFrame,
            rowContentHeight: 0,
            visibleFrame: visibleFrame,
            tokenUsageVisible: content.tokenUsage != nil
        )
        let rowHeights = QuotaDetailRowMetrics.heights(
            for: content.rows,
            cardWidth: widthFrame.width,
            remainingPercent: content.remainingPercent
        )
        let frame = QuotaDetailLayout.frame(
            indicatorFrame: indicatorFrame,
            rowContentHeight: rowHeights.reduce(0, +),
            visibleFrame: visibleFrame,
            tokenUsageVisible: content.tokenUsage != nil
        )
        return QuotaDetailPanelResolvedLayout(
            frame: frame,
            rowHeights: rowHeights
        )
    }
}

@MainActor
final class QuotaDetailCardView: NSView {
    init(
        frame frameRect: NSRect,
        content: QuotaDetailContent,
        rowHeights: [CGFloat],
        version: String? = nil,
        onOpenURL: @escaping (URL) -> Void
    ) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 18
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true

        let material = QuotaCardMaterialView(frame: bounds)
        material.autoresizingMask = [.width, .height]
        addSubview(material)

        let title = label(
            content.title,
            font: .systemFont(ofSize: 18, weight: .semibold),
            color: .labelColor,
            alignment: .left
        )
        title.lineBreakMode = .byTruncatingTail

        let displayedVersion = version ?? (
            Bundle.main.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String ?? "dev"
        )
        let versionBadge = VersionBadgeView(text: "v\(displayedVersion)")

        let remaining = label(
            "\(content.remainingPercent)%",
            font: .systemFont(ofSize: 28, weight: .semibold),
            color: QuotaColorScale.components(
                remainingPercent: content.remainingPercent
            ).appKitColor,
            alignment: .left
        )
        let headerFrames = QuotaDetailLayout.headerFrames(
            in: bounds,
            titleWidth: QuotaDetailLayout.titleWidth(
                intrinsicWidth: title.intrinsicContentSize.width,
                fittingWidth: title.fittingSize.width
            ),
            versionBadgeWidth: versionBadge.intrinsicContentSize.width
        )
        let avatar = QuotaAvatarView()
        avatar.frame = CGRect(
            x: QuotaDetailLayout.contentHorizontalInset,
            y: bounds.maxY - 50,
            width: 32,
            height: 32
        )
        title.frame = headerFrames.title
        versionBadge.frame = headerFrames.versionBadge
        remaining.frame = headerFrames.remaining
        addSubview(avatar)
        addSubview(title)
        addSubview(versionBadge)
        addSubview(remaining)

        if let summary = content.remainingSummary {
            let summaryLabel = label(
                summary,
                font: .systemFont(ofSize: 13, weight: .regular),
                color: .secondaryLabelColor,
                alignment: .left
            )
            summaryLabel.frame = CGRect(
                x: headerFrames.remaining.minX,
                y: bounds.maxY - 139,
                width: bounds.width - QuotaDetailLayout.contentHorizontalInset * 2,
                height: 18
            )
            addSubview(summaryLabel)
        }

        let progress = QuotaProgressView(
            frame: headerFrames.progress,
            value: content.remainingPercent
        )
        addSubview(progress)

        let informationFrames = QuotaDetailLayout.informationFrames(
            in: bounds,
            tokenUsageVisible: content.tokenUsage != nil
        )
        let topDivider = NSBox(
            frame: informationFrames.topDivider
        )
        topDivider.boxType = .separator
        addSubview(topDivider)

        if let tokenUsage = content.tokenUsage {
            let tokenUsageView = QuotaTokenUsageView(
                frame: informationFrames.tokenBand,
                presentation: tokenUsage,
                remainingPercent: content.remainingPercent
            )
            addSubview(tokenUsageView)
        }

        let rowAreaFrame = informationFrames.rowArea
        let scrollView = NSScrollView(frame: rowAreaFrame)
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = rowHeights.reduce(0, +) > rowAreaFrame.height
        scrollView.autohidesScrollers = true

        let rowContentWidth = scrollView.contentSize.width
        let effectiveRowHeights = scrollView.hasVerticalScroller
            ? QuotaDetailRowMetrics.heights(
                for: content.rows,
                cardWidth: rowContentWidth,
                remainingPercent: content.remainingPercent
            )
            : rowHeights
        let rowDocumentHeight = effectiveRowHeights.reduce(0, +)
        let rowDocument = FlippedView(
            frame: CGRect(
                x: 0,
                y: 0,
                width: rowContentWidth,
                height: max(rowAreaFrame.height, rowDocumentHeight)
            )
        )

        var rowY: CGFloat = 0
        for (index, row) in content.rows.enumerated() {
            let rowHeight = effectiveRowHeights[index]
            let isStacked = rowHeight > QuotaDetailLayout.rowHeight
            let icon = QuotaDetailIconView(
                kind: QuotaDetailIconKind.kind(
                    forRowAt: index,
                    count: content.rows.count
                )
            )
            icon.frame = CGRect(
                x: QuotaDetailLayout.contentHorizontalInset,
                y: rowY + 5,
                width: 18,
                height: 18
            )
            rowDocument.addSubview(icon)
            let rowLabel = label(
                row.label,
                font: QuotaDetailRowMetrics.labelFont,
                color: .labelColor,
                alignment: .left
            )
            let labelWidth = min(
                118,
                ceil(rowLabel.intrinsicContentSize.width + 2)
            )
            rowLabel.frame = CGRect(
                x: 42,
                y: rowY + 7,
                width: labelWidth,
                height: 16
            )
            rowDocument.addSubview(rowLabel)

            let value = label(
                row.value,
                font: QuotaDetailRowMetrics.valueFont,
                color: .labelColor,
                alignment: .right
            )
            value.attributedStringValue = QuotaDetailValueTypography.string(
                for: row,
                remainingPercent: content.remainingPercent
            )
            if isStacked {
                let valueHeight = rowHeight - 18
                value.maximumNumberOfLines = Int(valueHeight / 15)
                value.lineBreakMode = .byCharWrapping
                value.frame = CGRect(
                    x: 42,
                    y: rowY + 18,
                    width: rowContentWidth - 52,
                    height: valueHeight
                )
            } else {
                value.lineBreakMode = .byTruncatingTail
                let valueX = max(148, rowLabel.frame.maxX + 10)
                value.frame = CGRect(
                    x: valueX,
                    y: rowY + 7,
                    width: rowContentWidth - valueX - 12,
                    height: 16
                )
            }
            rowDocument.addSubview(value)
            if index < content.rows.indices.last! {
                let separator = NSBox(
                    frame: CGRect(
                        x: 42,
                        y: rowY + rowHeight - 1,
                        width: max(0, rowContentWidth - 54),
                        height: 1
                    )
                )
                separator.boxType = .separator
                rowDocument.addSubview(separator)
            }
            rowY += rowHeight
        }

        scrollView.documentView = rowDocument
        addSubview(scrollView)

        let footerDivider = NSBox(frame: informationFrames.footerDivider)
        footerDivider.boxType = .separator
        addSubview(footerDivider)
        addSubview(QuotaFooterView(frame: informationFrames.footer))
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
private final class QuotaFooterView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let avatar = QuotaAvatarView(frame: CGRect(x: 18, y: 9, width: 30, height: 30))
        addSubview(avatar)

        let name = NSTextField(labelWithString: "Jace")
        name.font = .systemFont(ofSize: 14, weight: .regular)
        name.textColor = .labelColor
        name.frame = CGRect(x: 58, y: 16, width: 120, height: 20)
        addSubview(name)

        let help = QuotaFooterHelpButton(frame: CGRect(x: frameRect.width - 46, y: 11, width: 28, height: 28))
        addSubview(help)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }
}

@MainActor
private final class QuotaFooterHelpButton: NSButton {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        title = "?"
        isBordered = false
        setButtonType(.momentaryPushIn)
        font = .systemFont(ofSize: 15, weight: .medium)
        contentTintColor = .secondaryLabelColor
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("Help")
    }

    override func draw(_ dirtyRect: NSRect) {
        let circle = NSBezierPath(ovalIn: bounds.insetBy(dx: 0.75, dy: 0.75))
        NSColor.secondaryLabelColor.setStroke()
        circle.lineWidth = 1.5
        circle.stroke()
        super.draw(dirtyRect)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }
}

@MainActor
final class QuotaReferenceTiboOutlineView: NSView {
    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let outline = NSBezierPath(
            roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
            xRadius: 10,
            yRadius: 10
        )
        NSColor.separatorColor.withAlphaComponent(0.78).setStroke()
        outline.lineWidth = 1
        outline.stroke()
    }
}

@MainActor
private final class VersionBadgeView: NSView {
    private let text: String
    private let font = NSFont.systemFont(
        ofSize: 12,
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
        return NSSize(width: ceil(textSize.width) + 14, height: 22)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let capsuleBounds = bounds.insetBy(dx: 0.5, dy: 0.5)
        let capsule = NSBezierPath(
            roundedRect: capsuleBounds,
            xRadius: capsuleBounds.height / 2,
            yRadius: capsuleBounds.height / 2
        )
        NSColor.separatorColor.withAlphaComponent(0.86).setStroke()
        capsule.lineWidth = 1
        capsule.stroke()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.secondaryLabelColor
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
private final class QuotaAvatarView: NSView {
    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let circle = NSBezierPath(ovalIn: bounds.insetBy(dx: 0.5, dy: 0.5))
        NSGraphicsContext.saveGraphicsState()
        circle.addClip()
        let background = NSGradient(
            starting: NSColor(calibratedRed: 0.18, green: 0.16, blue: 0.30, alpha: 1),
            ending: NSColor(calibratedRed: 0.27, green: 0.33, blue: 0.55, alpha: 1)
        )
        background?.draw(in: bounds, angle: 35)

        let shoulders = NSBezierPath(roundedRect: CGRect(
            x: bounds.midX - bounds.width * 0.33,
            y: bounds.minY - 2,
            width: bounds.width * 0.66,
            height: bounds.height * 0.48
        ), xRadius: bounds.width * 0.2, yRadius: bounds.width * 0.2)
        NSColor(calibratedRed: 0.72, green: 0.48, blue: 0.32, alpha: 1).setFill()
        shoulders.fill()

        let face = NSBezierPath(ovalIn: CGRect(
            x: bounds.midX - bounds.width * 0.22,
            y: bounds.midY - bounds.height * 0.24,
            width: bounds.width * 0.44,
            height: bounds.height * 0.54
        ))
        NSColor(calibratedRed: 0.83, green: 0.64, blue: 0.46, alpha: 1).setFill()
        face.fill()

        let hair = NSBezierPath(ovalIn: CGRect(
            x: bounds.midX - bounds.width * 0.30,
            y: bounds.midY - bounds.height * 0.33,
            width: bounds.width * 0.60,
            height: bounds.height * 0.62
        ))
        NSColor(calibratedRed: 0.10, green: 0.08, blue: 0.07, alpha: 1).setFill()
        hair.fill()
        face.fill()
        NSGraphicsContext.restoreGraphicsState()

        NSColor.separatorColor.withAlphaComponent(0.42).setStroke()
        circle.lineWidth = 0.75
        circle.stroke()
    }
}

@MainActor
private enum QuotaDetailRowMetrics {
    static let labelFont = NSFont.systemFont(ofSize: 13, weight: .semibold)
    static let valueFont = NSFont.systemFont(ofSize: 12, weight: .regular)

    static func heights(
        for rows: [QuotaDetailRow],
        cardWidth: CGFloat,
        remainingPercent: Int
    ) -> [CGFloat] {
        rows.map { row in
            let labelWidth = min(118, textWidth(row.label, font: labelFont) + 2)
            let valueX = max(148, 42 + labelWidth + 10)
            let columnWidth = max(1, cardWidth - valueX - 12)
            let measuredValueWidth = ceil(
                QuotaDetailValueTypography.string(
                    for: row,
                    remainingPercent: remainingPercent
                ).size().width
            )
            guard measuredValueWidth > columnWidth else {
                return QuotaDetailLayout.rowHeight
            }

            let fullWidth = max(1, cardWidth - 54)
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
        ofSize: 15,
        weight: .semibold
    )
    private static let unitFont = NSFont.systemFont(
        ofSize: 11,
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
private enum QuotaDetailValueTypography {
    static func string(
        for row: QuotaDetailRow,
        remainingPercent: Int
    ) -> NSAttributedString {
        switch row.valueStyle {
        case .standard:
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .right
            return NSAttributedString(
                string: row.value,
                attributes: [
                    .font: QuotaDetailRowMetrics.valueFont,
                    .foregroundColor: NSColor.labelColor,
                    .paragraphStyle: paragraph
                ]
            )
        case .resetCountdown:
            return QuotaCountdownTypography.string(
                row.value,
                remainingPercent: remainingPercent
            )
        }
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
