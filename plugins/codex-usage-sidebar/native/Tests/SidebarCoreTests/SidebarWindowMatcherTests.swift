import CoreGraphics
import SidebarCore
import XCTest

final class SidebarWindowMatcherTests: XCTestCase {
    func testSelectsWindowMatchingObservedGeometryInsteadOfFirstWindow() {
        let expected = CGRect(x: 89, y: 31, width: 1_831, height: 1_049)
        let windows = [
            CGRect(x: 200, y: 150, width: 900, height: 700),
            CGRect(x: 90, y: 30, width: 1_830, height: 1_050),
        ]

        XCTAssertEqual(
            SidebarWindowMatcher.bestMatchIndex(
                windowFrames: windows,
                expectedFrame: expected
            ),
            1
        )
    }

    func testRejectsWindowsThatDoNotMatchObservedGeometry() {
        let expected = CGRect(x: 89, y: 31, width: 1_831, height: 1_049)
        let windows = [CGRect(x: 900, y: 400, width: 500, height: 400)]

        XCTAssertNil(
            SidebarWindowMatcher.bestMatchIndex(
                windowFrames: windows,
                expectedFrame: expected
            )
        )
    }
}
