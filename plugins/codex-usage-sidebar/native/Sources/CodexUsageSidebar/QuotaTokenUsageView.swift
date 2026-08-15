import AppKit
import SidebarCore

@MainActor
final class QuotaTokenUsageView: NSView {
    private static let titleFont = NSFont.systemFont(ofSize: 12, weight: .semibold)
    private static let totalFont = NSFont.systemFont(ofSize: 10, weight: .medium)
    private static let noteFont = NSFont.systemFont(ofSize: 9, weight: .regular)
    private static let minimumDayWidth: CGFloat = 38

    let barCount: Int

    init(
        frame frameRect: NSRect,
        presentation: QuotaTokenUsagePresentation,
        remainingPercent: Int
    ) {
        barCount = presentation.days.count
        super.init(frame: frameRect)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(presentation.title)
        setAccessibilityValue(
            presentation.availability == .available
                ? presentation.totalLabel
                : presentation.delayNote
        )

        let title = label(
            presentation.title,
            font: Self.titleFont,
            color: .labelColor,
            alignment: .left
        )
        title.frame = CGRect(x: 0, y: bounds.height - 18, width: 104, height: 16)
        addSubview(title)

        let total = label(
            presentation.totalLabel,
            font: Self.totalFont,
            color: .secondaryLabelColor,
            alignment: .right
        )
        total.lineBreakMode = .byTruncatingHead
        total.frame = CGRect(
            x: 106,
            y: bounds.height - 17,
            width: max(0, bounds.width - 106),
            height: 14
        )
        addSubview(total)

        let note = label(
            presentation.delayNote,
            font: Self.noteFont,
            color: .tertiaryLabelColor,
            alignment: .left
        )
        note.lineBreakMode = .byTruncatingTail
        note.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 12)
        addSubview(note)

        guard presentation.availability == .available,
              !presentation.days.isEmpty
        else {
            return
        }

        let chartFrame = CGRect(
            x: 0,
            y: 14,
            width: bounds.width,
            height: max(0, bounds.height - 35)
        )
        let scrollView = NSScrollView(frame: chartFrame)
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        let documentWidth = max(
            chartFrame.width,
            CGFloat(presentation.days.count) * Self.minimumDayWidth
        )
        scrollView.hasHorizontalScroller = documentWidth > chartFrame.width
        scrollView.documentView = TokenUsageChartView(
            frame: CGRect(
                x: 0,
                y: 0,
                width: documentWidth,
                height: chartFrame.height
            ),
            days: presentation.days,
            remainingPercent: remainingPercent
        )
        addSubview(scrollView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    private func label(
        _ text: String,
        font: NSFont,
        color: NSColor,
        alignment: NSTextAlignment
    ) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = font
        field.textColor = color
        field.alignment = alignment
        field.maximumNumberOfLines = 1
        field.isSelectable = false
        return field
    }
}

@MainActor
private final class TokenUsageChartView: NSView {
    init(
        frame frameRect: NSRect,
        days: [QuotaTokenUsageDay],
        remainingPercent: Int
    ) {
        super.init(frame: frameRect)
        let maximum = max(1, days.map(\.tokens).max() ?? 0)
        let columnWidth = bounds.width / CGFloat(max(1, days.count))
        for (index, day) in days.enumerated() {
            let height = max(
                3,
                floor(24 * CGFloat(day.tokens) / CGFloat(maximum))
            )
            let bar = TokenUsageBarView(
                frame: CGRect(
                    x: CGFloat(index) * columnWidth,
                    y: 0,
                    width: columnWidth,
                    height: bounds.height
                ),
                day: day,
                barHeight: height,
                remainingPercent: remainingPercent
            )
            addSubview(bar)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }
}

@MainActor
private final class TokenUsageBarView: NSView {
    private let day: QuotaTokenUsageDay
    private let barHeight: CGFloat
    private let remainingPercent: Int
    private let numberFont = NSFont.systemFont(ofSize: 9, weight: .medium)
    private let dateFont = NSFont.systemFont(ofSize: 8, weight: .regular)

    init(
        frame frameRect: NSRect,
        day: QuotaTokenUsageDay,
        barHeight: CGFloat,
        remainingPercent: Int
    ) {
        self.day = day
        self.barHeight = barHeight
        self.remainingPercent = remainingPercent
        super.init(frame: frameRect)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(day.label)
        setAccessibilityValue(Self.tokenLabel(day.tokens))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let labelColor: NSColor = day.isCurrentDay
            ? QuotaColorScale.components(
                remainingPercent: remainingPercent
            ).appKitColor
            : .secondaryLabelColor
        let value = Self.tokenLabel(day.tokens) as NSString
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: numberFont,
            .foregroundColor: labelColor
        ]
        let valueSize = value.size(withAttributes: valueAttributes)
        value.draw(
            at: CGPoint(
                x: floor((bounds.width - valueSize.width) / 2),
                y: bounds.height - 11
            ),
            withAttributes: valueAttributes
        )

        let fillColor: NSColor = day.isCurrentDay
            ? QuotaColorScale.components(
                remainingPercent: remainingPercent
            ).appKitColor
            : NSColor.secondaryLabelColor.withAlphaComponent(0.38)
        let barRect = CGRect(
            x: floor((bounds.width - 12) / 2),
            y: 11,
            width: 12,
            height: min(barHeight, max(3, bounds.height - 28))
        )
        let path = NSBezierPath(roundedRect: barRect, xRadius: 2, yRadius: 2)
        fillColor.setFill()
        path.fill()

        let date = day.label as NSString
        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: dateFont,
            .foregroundColor: NSColor.tertiaryLabelColor
        ]
        let dateSize = date.size(withAttributes: dateAttributes)
        date.draw(
            at: CGPoint(
                x: floor((bounds.width - dateSize.width) / 2),
                y: 0
            ),
            withAttributes: dateAttributes
        )
    }

    private static func tokenLabel(_ tokens: Int64) -> String {
        switch tokens {
        case 1_000_000...:
            return String(format: "%.1fM", Double(tokens) / 1_000_000)
        case 1_000...:
            return String(format: "%.0fK", Double(tokens) / 1_000)
        default:
            return String(tokens)
        }
    }
}
