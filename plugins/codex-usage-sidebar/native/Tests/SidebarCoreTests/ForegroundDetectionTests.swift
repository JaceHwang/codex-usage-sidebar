import CoreGraphics
import XCTest
@testable import SidebarCore

final class ForegroundDetectionTests: XCTestCase {
    func testUsesFirstUsableNormalLayerWindow() {
        let windows = [
            WindowOwner(
                processIdentifier: 900,
                layer: 25,
                frame: CGRect(x: 0, y: 0, width: 100, height: 100)
            ),
            WindowOwner(
                processIdentifier: 42,
                layer: 0,
                frame: CGRect(x: 0, y: 0, width: 1200, height: 800)
            ),
            WindowOwner(
                processIdentifier: 77,
                layer: 0,
                frame: CGRect(x: 20, y: 20, width: 900, height: 600)
            )
        ]

        XCTAssertTrue(
            ForegroundWindowDetector.isHostFrontmost(
                hostProcessIdentifier: 42,
                orderedWindows: windows
            )
        )
        XCTAssertFalse(
            ForegroundWindowDetector.isHostFrontmost(
                hostProcessIdentifier: 77,
                orderedWindows: windows
            )
        )
    }

    func testIgnoresZeroSizedUtilityWindows() {
        let windows = [
            WindowOwner(
                processIdentifier: 77,
                layer: 0,
                frame: .zero
            ),
            WindowOwner(
                processIdentifier: 42,
                layer: 0,
                frame: CGRect(x: 0, y: 0, width: 1200, height: 800)
            )
        ]

        XCTAssertTrue(
            ForegroundWindowDetector.isHostFrontmost(
                hostProcessIdentifier: 42,
                orderedWindows: windows
            )
        )
    }
}
