import CoreGraphics
import XCTest
@testable import SidebarCore

final class TitlebarControlResolverTests: XCTestCase {
    func testReturnsLeadingEdgeOfFirstCompactRightTitlebarControl() {
        let window = CGRect(x: 72, y: 1, width: 1_847, height: 1_048)
        let candidates = [
            SidebarToggleCandidate(
                frame: CGRect(x: 177, y: 1_012, width: 28, height: 28),
                role: "AXButton",
                description: "Show Sidebar"
            ),
            SidebarToggleCandidate(
                frame: CGRect(x: 1_748, y: 1_012, width: 28, height: 28),
                role: "AXButton",
                description: "New Chat"
            ),
            SidebarToggleCandidate(
                frame: CGRect(x: 1_784, y: 1_012, width: 28, height: 28),
                role: "AXButton",
                description: "More Actions"
            ),
            SidebarToggleCandidate(
                frame: CGRect(x: 1_780, y: 900, width: 28, height: 28),
                role: "AXButton",
                description: "Content Action"
            ),
        ]

        XCTAssertEqual(
            TitlebarControlResolver.leadingEdge(
                candidates: candidates,
                windowFrame: window
            ),
            1_748
        )
    }
}
