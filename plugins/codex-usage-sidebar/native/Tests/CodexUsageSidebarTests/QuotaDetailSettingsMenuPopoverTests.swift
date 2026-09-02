import AppKit
import SidebarCore
import XCTest
@testable import CodexUsageSidebar

@MainActor
final class QuotaDetailSettingsMenuPopoverTests: XCTestCase {
    func testMenuAnchorsAboveSettingsButtonAndSubmenuUsesTheVisibleScreenFrame() {
        let popover = QuotaDetailSettingsMenuPopover()
        let settingsButton = CGRect(x: 620, y: 40, width: 30, height: 30)

        popover.show(
            relativeTo: settingsButton,
            mode: .automatic,
            localization: QuotaLocalization(language: .simplifiedChinese),
            theme: .dark,
            onPlacementModeSelected: { _ in },
            onCheckForUpdates: {},
            onReload: {},
            onQuit: {}
        )
        popover.showPositionModeSubmenu()

        XCTAssertEqual(popover.parentFrame?.maxX, settingsButton.maxX)
        XCTAssertEqual(popover.parentFrame?.minY, settingsButton.maxY + 6)
        XCTAssertEqual(
            popover.submenuFrame?.minX,
            (popover.parentFrame?.maxX ?? -1) + 4
        )
        XCTAssertEqual(popover.submenuFrame?.maxY, popover.parentFrame?.maxY)
        popover.hide()
    }

    func testSubmenuClosesAfterPointerLeavesPositionModeAndSubmenu() {
        let popover = QuotaDetailSettingsMenuPopover()
        popover.show(
            relativeTo: CGRect(x: 620, y: 40, width: 30, height: 30),
            mode: .automatic,
            localization: QuotaLocalization(language: .simplifiedChinese),
            theme: .dark,
            onPlacementModeSelected: { _ in },
            onCheckForUpdates: {},
            onReload: {},
            onQuit: {}
        )
        popover.showPositionModeSubmenu()

        XCTAssertNotNil(popover.submenuFrame)

        popover.updateSubmenuVisibility(
            isPointerOverPositionMode: false,
            isPointerOverSubmenu: false
        )

        XCTAssertNil(popover.submenuFrame)
        popover.hide()
    }

    func testSubmenuRemainsVisibleWhilePointerMovesIntoSubmenu() {
        let popover = QuotaDetailSettingsMenuPopover()
        popover.show(
            relativeTo: CGRect(x: 620, y: 40, width: 30, height: 30),
            mode: .automatic,
            localization: QuotaLocalization(language: .simplifiedChinese),
            theme: .dark,
            onPlacementModeSelected: { _ in },
            onCheckForUpdates: {},
            onReload: {},
            onQuit: {}
        )
        popover.showPositionModeSubmenu()

        popover.updateSubmenuVisibility(
            isPointerOverPositionMode: false,
            isPointerOverSubmenu: true
        )

        XCTAssertNotNil(popover.submenuFrame)
        popover.hide()
    }
}
