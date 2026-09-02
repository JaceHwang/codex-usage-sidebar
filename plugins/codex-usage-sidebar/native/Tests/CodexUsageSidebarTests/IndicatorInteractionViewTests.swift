import AppKit
import SidebarCore
import XCTest
@testable import CodexUsageSidebar

@MainActor
final class IndicatorInteractionViewTests: XCTestCase {
    func testFreeDragForwardsEveryMouseDraggedEventImmediately() {
        let view = IndicatorInteractionView(
            frame: CGRect(x: 0, y: 0, width: 180, height: 46)
        )
        view.mode = .free
        var beganCount = 0
        var deltas: [CGPoint] = []
        var endedCount = 0
        view.onDragBegan = { beganCount += 1 }
        view.onDrag = { deltas.append($0) }
        view.onDragEnded = { endedCount += 1 }

        view.mouseDown(with: mouseEvent(.leftMouseDown, at: CGPoint(x: 10, y: 10)))
        view.mouseDragged(with: mouseEvent(.leftMouseDragged, at: CGPoint(x: 16, y: 10)))
        view.mouseDragged(with: mouseEvent(.leftMouseDragged, at: CGPoint(x: 52, y: 34)))
        view.mouseUp(with: mouseEvent(.leftMouseUp, at: CGPoint(x: 52, y: 34)))

        XCTAssertEqual(beganCount, 1)
        XCTAssertEqual(deltas, [CGPoint(x: 6, y: 0), CGPoint(x: 42, y: 24)])
        XCTAssertEqual(endedCount, 1)
    }

    func testFreeDragUsesStableScreenCoordinatesAfterThePanelMoves() {
        let view = IndicatorInteractionView(
            frame: CGRect(x: 0, y: 0, width: 180, height: 46)
        )
        view.mode = .free
        var points = [
            CGPoint(x: 800, y: 600),
            CGPoint(x: 836, y: 624),
            CGPoint(x: 892, y: 658)
        ]
        view.screenPointResolver = { _ in
            points.removeFirst()
        }
        var deltas: [CGPoint] = []
        view.onDrag = { deltas.append($0) }

        view.mouseDown(with: mouseEvent(.leftMouseDown, at: CGPoint(x: 10, y: 10)))
        // These local points intentionally do not maintain a stable delta:
        // the panel would have moved after the first drag event.
        view.mouseDragged(with: mouseEvent(.leftMouseDragged, at: CGPoint(x: 46, y: 34)))
        view.mouseDragged(with: mouseEvent(.leftMouseDragged, at: CGPoint(x: 56, y: 34)))

        XCTAssertEqual(deltas, [CGPoint(x: 36, y: 24), CGPoint(x: 92, y: 58)])
    }

    private func mouseEvent(
        _ type: NSEvent.EventType,
        at point: CGPoint
    ) -> NSEvent {
        NSEvent.mouseEvent(
            with: type,
            location: point,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        )!
    }
}
