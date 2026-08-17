import AppKit
import XCTest
@testable import CodexUsageSidebar

@MainActor
final class QuotaFooterGitHubButtonTests: XCTestCase {
    func testExposesProjectLinkAccessibilityAndOpensExactURL() {
        let destination = URL(string: "https://github.com/JaceHwang/codex-usage-sidebar")!
        var opened: URL?
        let button = QuotaFooterGitHubButton(
            frame: CGRect(x: 0, y: 0, width: 22, height: 22),
            destination: destination,
            onActivate: { opened = $0 }
        )

        XCTAssertEqual(button.accessibilityRole(), .link)
        XCTAssertEqual(button.accessibilityLabel(), "GitHub")
        XCTAssertEqual(button.accessibilityHelp(), destination.absoluteString)

        button.activateLink()

        XCTAssertEqual(opened, destination)
    }
}
