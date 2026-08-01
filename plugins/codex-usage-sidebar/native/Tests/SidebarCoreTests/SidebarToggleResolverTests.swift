import CoreGraphics
import XCTest
@testable import SidebarCore

final class SidebarToggleResolverTests: XCTestCase {
    private let window = CGRect(x: 72, y: 1, width: 1_847, height: 1_048)
    private let toggleFrame = CGRect(x: 177, y: 1_012, width: 28, height: 28)

    func testChineseHideDescriptionMeansSidebarIsVisible() {
        XCTAssertEqual(
            placement(description: "隐藏边栏"),
            .sidebar
        )
    }

    func testChineseShowDescriptionMeansSidebarIsHidden() {
        XCTAssertEqual(
            placement(description: "显示边栏"),
            .titlebar
        )
    }

    func testEnglishDescriptionsResolveBothStates() {
        XCTAssertEqual(placement(description: "Hide Sidebar"), .sidebar)
        XCTAssertEqual(placement(description: "Show Sidebar"), .titlebar)
    }

    func testIgnoresRightSidebarCheckboxAndUnrelatedToolbarButtons() {
        let candidates = [
            SidebarToggleCandidate(
                frame: CGRect(x: 1_884, y: 1_012, width: 28, height: 28),
                role: "AXCheckBox",
                description: "显示/隐藏侧边栏"
            ),
            SidebarToggleCandidate(
                frame: CGRect(x: 209, y: 1_012, width: 28, height: 28),
                role: "AXButton",
                description: "返回"
            )
        ]

        XCTAssertNil(
            SidebarToggleResolver.placement(
                candidates: candidates,
                windowFrame: window
            )
        )
    }

    func testAmbiguousToggleDescriptionsReturnNil() {
        let candidates = [
            SidebarToggleCandidate(
                frame: toggleFrame,
                role: "AXButton",
                description: "隐藏边栏"
            ),
            SidebarToggleCandidate(
                frame: toggleFrame.offsetBy(dx: 2, dy: 0),
                role: "AXButton",
                description: "显示边栏"
            )
        ]

        XCTAssertNil(
            SidebarToggleResolver.placement(
                candidates: candidates,
                windowFrame: window
            )
        )
    }

    func testEquivalentDuplicateToggleDescriptionsResolveOnce() {
        let duplicate = SidebarToggleCandidate(
            frame: toggleFrame,
            role: "AXButton",
            description: "显示边栏"
        )

        XCTAssertEqual(
            SidebarToggleResolver.placement(
                candidates: [duplicate, duplicate],
                windowFrame: window
            ),
            .titlebar
        )
    }

    func testVisibleSidebarNavigationOverridesStaleToggleDescription() {
        let staleToggle = SidebarToggleCandidate(
            frame: toggleFrame,
            role: "AXButton",
            description: "显示边栏"
        )
        let navigation = [
            SidebarToggleCandidate(
                frame: CGRect(x: 110, y: 880, width: 260, height: 32),
                role: "AXButton",
                description: "搜索"
            ),
            SidebarToggleCandidate(
                frame: CGRect(x: 110, y: 830, width: 260, height: 32),
                role: "AXButton",
                description: "快速聊天"
            ),
        ]

        XCTAssertEqual(
            SidebarToggleResolver.placement(
                candidates: [staleToggle] + navigation,
                windowFrame: window
            ),
            .sidebar
        )
    }

    func testOrdinaryLeftSideButtonsCannotOverrideCollapsedToggle() {
        let collapsedToggle = SidebarToggleCandidate(
            frame: toggleFrame,
            role: "AXButton",
            description: "显示边栏"
        )
        let ordinaryContentButtons = [
            SidebarToggleCandidate(
                frame: CGRect(x: 110, y: 880, width: 260, height: 32),
                role: "AXButton",
                description: "运行"
            ),
            SidebarToggleCandidate(
                frame: CGRect(x: 110, y: 830, width: 260, height: 32),
                role: "AXButton",
                description: "取消"
            ),
        ]

        XCTAssertEqual(
            SidebarToggleResolver.placement(
                candidates: [collapsedToggle] + ordinaryContentButtons,
                windowFrame: window
            ),
            .titlebar
        )
    }

    private func placement(description: String) -> OverlayPlacement? {
        SidebarToggleResolver.placement(
            candidates: [
                SidebarToggleCandidate(
                    frame: toggleFrame,
                    role: "AXButton",
                    description: description
                )
            ],
            windowFrame: window
        )
    }
}
