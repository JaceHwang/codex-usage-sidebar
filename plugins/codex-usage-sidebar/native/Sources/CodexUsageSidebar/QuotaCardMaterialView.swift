import AppKit

enum QuotaChromeStyle {
    static let separatorLineWidth: CGFloat = 1
    static let separatorAlpha: CGFloat = 0.78

    static var separatorColor: NSColor {
        NSColor.separatorColor.withAlphaComponent(separatorAlpha)
    }
}

@MainActor
final class QuotaCardMaterialView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    override var isOpaque: Bool { false }

    func shadowOpacity(for appearanceName: NSAppearance.Name) -> Float {
        appearanceName == .darkAqua ? 0.40 : 0.18
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let cardBounds = bounds.insetBy(dx: 0.5, dy: 0.5)
        let card = NSBezierPath(
            roundedRect: cardBounds,
            xRadius: 17.5,
            yRadius: 17.5
        )
        let appearanceName = effectiveAppearance.bestMatch(
            from: [.darkAqua, .aqua]
        )
        let fill: NSColor
        let shadowColor: NSColor
        if appearanceName == .darkAqua {
            fill = NSColor(calibratedWhite: 0.09, alpha: 0.98)
            shadowColor = NSColor.black.withAlphaComponent(0.28)
        } else {
            fill = NSColor.windowBackgroundColor.withAlphaComponent(0.98)
            shadowColor = NSColor.black.withAlphaComponent(0.14)
        }

        let shadow = NSShadow()
        shadow.shadowColor = shadowColor
        shadow.shadowOffset = NSSize(width: 0, height: -2)
        shadow.shadowBlurRadius = 10
        shadow.set()
        fill.setFill()
        card.fill()
        QuotaChromeStyle.separatorColor.setStroke()
        card.lineWidth = QuotaChromeStyle.separatorLineWidth
        card.stroke()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }
}
