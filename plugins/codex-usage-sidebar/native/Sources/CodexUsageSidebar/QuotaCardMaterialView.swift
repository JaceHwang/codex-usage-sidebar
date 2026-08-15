import AppKit

@MainActor
final class QuotaCardMaterialView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let cardBounds = bounds.insetBy(dx: 0.5, dy: 0.5)
        let card = NSBezierPath(
            roundedRect: cardBounds,
            xRadius: 27.5,
            yRadius: 27.5
        )
        let appearanceName = effectiveAppearance.bestMatch(
            from: [.darkAqua, .aqua]
        )
        let fill: NSColor
        let border: NSColor
        if appearanceName == .darkAqua {
            fill = NSColor(calibratedWhite: 0.12, alpha: 0.97)
            border = NSColor(calibratedWhite: 0.52, alpha: 0.56)
        } else {
            fill = NSColor.windowBackgroundColor.withAlphaComponent(0.98)
            border = NSColor.separatorColor.withAlphaComponent(0.72)
        }

        fill.setFill()
        card.fill()
        border.setStroke()
        card.lineWidth = 1
        card.stroke()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }
}
