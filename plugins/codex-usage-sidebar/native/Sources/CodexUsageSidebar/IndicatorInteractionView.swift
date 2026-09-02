import AppKit
import SidebarCore

@MainActor
final class IndicatorInteractionView: NSView {
    var mode: IndicatorPlacementMode = .automatic
    var onPrimaryClick: (() -> Void)?
    var onSecondaryClick: (() -> Void)?
    var onDragBegan: (() -> Void)?
    var onDrag: ((CGPoint) -> Void)?
    var onDragEnded: (() -> Void)?
    var screenPointResolver: ((NSEvent) -> CGPoint)?
    private var dragSession = IndicatorDragSession()

    var isDraggingIndicator: Bool {
        dragSession.isDragging
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        guard mode == .free else { return }
        addCursorRect(bounds, cursor: .openHand)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    override func rightMouseDown(with event: NSEvent) {
        onSecondaryClick?()
    }

    override func mouseDown(with event: NSEvent) {
        dragSession.begin(at: screenPoint(for: event))
    }

    override func mouseDragged(with event: NSEvent) {
        let wasDragging = dragSession.isDragging
        guard let delta = dragSession.update(
            to: screenPoint(for: event),
            mode: mode
        ) else {
            return
        }
        if !wasDragging, dragSession.isDragging {
            NSCursor.closedHand.set()
            onDragBegan?()
        }
        onDrag?(delta)
    }

    override func mouseUp(with event: NSEvent) {
        if dragSession.end() {
            onDragEnded?()
        } else {
            onPrimaryClick?()
        }
        window?.invalidateCursorRects(for: self)
    }

    private func screenPoint(for event: NSEvent) -> CGPoint {
        if let screenPointResolver {
            return screenPointResolver(event)
        }
        guard let window else {
            return event.locationInWindow
        }
        return window.convertPoint(toScreen: event.locationInWindow)
    }
}
