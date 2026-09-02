import CoreGraphics
import SidebarCore
import XCTest

final class QuotaDetailSettingsMenuLayoutTests: XCTestCase {
    func testParentMenuSitsAboveAndRightAlignsWithSettingsButton() {
        let settingsButton = CGRect(x: 620, y: 40, width: 30, height: 30)

        let parent = QuotaDetailSettingsMenuLayout.parentFrame(
            settingsButtonFrame: settingsButton
        )

        XCTAssertEqual(parent.maxX, settingsButton.maxX)
        XCTAssertEqual(parent.minY, settingsButton.maxY + 6)
    }

    func testSubmenuStartsAtTheHoveredPositionModeRowTop() {
        let parent = CGRect(x: 450, y: 76, width: 200, height: 160)
        let visibleFrame = CGRect(x: 0, y: 0, width: 1_200, height: 800)

        let submenu = QuotaDetailSettingsMenuLayout.submenuFrame(
            parentFrame: parent,
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(submenu.minX, parent.maxX + 4)
        XCTAssertEqual(submenu.maxY, parent.maxY)
    }

    func testSubmenuFlipsToTheLeftWhenRightSideWouldOverflowVisibleFrame() {
        let parent = CGRect(x: 940, y: 76, width: 176, height: 160)
        let visibleFrame = CGRect(x: 0, y: 0, width: 1_200, height: 800)

        let submenu = QuotaDetailSettingsMenuLayout.submenuFrame(
            parentFrame: parent,
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(submenu.maxX, parent.minX - 4)
        XCTAssertEqual(submenu.maxY, parent.maxY)
        XCTAssertGreaterThanOrEqual(submenu.minX, visibleFrame.minX)
    }
}
