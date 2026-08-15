import AppKit
import SidebarCore
import XCTest
@testable import CodexUsageSidebar

@MainActor
final class QuotaInformationLinkButtonTests: XCTestCase {
    func testEntireVisibleRowRoutesClicksToTheLinkControl() {
        let button = makeButton()
        button.layoutSubtreeIfNeeded()

        let hitView = button.hitTest(CGPoint(x: 80, y: 16))

        XCTAssertTrue(hitView === button)
    }

    func testExposesLocalizedLinkAccessibility() {
        let button = makeButton()

        XCTAssertEqual(button.accessibilityRole(), .link)
        XCTAssertEqual(
            button.accessibilityLabel(),
            "Open Tibo's X profile in the browser"
        )
    }

    private func makeButton() -> QuotaInformationLinkButton {
        QuotaInformationLinkButton(
            frame: CGRect(x: 0, y: 0, width: 276, height: 32),
            entry: QuotaInformationEntry(
                title: "Tibo on X",
                accessibilityLabel: "Open Tibo's X profile in the browser",
                destination: URL(string: "https://x.com/thsottiaux")!
            ),
            onActivate: { _ in }
        )
    }
}
