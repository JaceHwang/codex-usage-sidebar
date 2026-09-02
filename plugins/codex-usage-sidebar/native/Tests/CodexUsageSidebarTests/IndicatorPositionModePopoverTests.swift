import AppKit
import SidebarCore
import XCTest
@testable import CodexUsageSidebar

@MainActor
final class IndicatorPositionModePopoverTests: XCTestCase {
    func testVisibleMenuRepositionsWithItsIndicator() {
        let popover = IndicatorPositionModePopover()
        let localization = QuotaLocalization(language: .english)
        let initial = CGRect(x: 300, y: 800, width: 164, height: 46)
        let moved = CGRect(x: 620, y: 620, width: 164, height: 46)

        popover.show(
            relativeTo: initial,
            mode: .free,
            localization: localization,
            theme: .light,
            onSelection: { _ in }
        )
        popover.reposition(relativeTo: moved)

        XCTAssertEqual(popover.frame?.minX, moved.minX)
        XCTAssertEqual(popover.frame?.maxY, moved.minY - 8)
        popover.hide()
    }
}
