import CoreGraphics
import XCTest
@testable import SidebarCore

final class AnchorScorerTests: XCTestCase {
    private let window = CGRect(x: 100, y: 80, width: 900, height: 700)

    func testFullProfileRowWinsOverSettingsAndNavigation() {
        let profile = AnchorCandidate(
            frame: CGRect(x: 112, y: 92, width: 220, height: 40),
            role: "AXButton",
            childRoles: ["AXImage", "AXStaticText"],
            siblingFrames: [CGRect(x: 340, y: 94, width: 36, height: 36)]
        )
        let settings = AnchorCandidate(
            frame: CGRect(x: 340, y: 94, width: 36, height: 36),
            role: "AXButton",
            childRoles: ["AXImage"],
            siblingFrames: [profile.frame]
        )
        let navigation = AnchorCandidate(
            frame: CGRect(x: 112, y: 300, width: 220, height: 40),
            role: "AXButton",
            childRoles: ["AXImage", "AXStaticText"],
            siblingFrames: []
        )

        XCTAssertEqual(
            AnchorScorer.bestCandidate(
                in: [settings, navigation, profile],
                window: window
            ),
            profile
        )
    }

    func testCollapsedSidebarReturnsNil() {
        let collapsed = AnchorCandidate(
            frame: CGRect(x: 112, y: 92, width: 44, height: 40),
            role: "AXButton",
            childRoles: ["AXImage"],
            siblingFrames: []
        )

        XCTAssertNil(AnchorScorer.bestCandidate(in: [collapsed], window: window))
    }

    func testAmbiguousPairReturnsNil() {
        let first = AnchorCandidate(
            frame: CGRect(x: 112, y: 92, width: 200, height: 40),
            role: "AXButton",
            childRoles: ["AXImage", "AXStaticText"],
            siblingFrames: []
        )
        let second = AnchorCandidate(
            frame: CGRect(x: 112, y: 96, width: 200, height: 40),
            role: "AXButton",
            childRoles: ["AXImage", "AXStaticText"],
            siblingFrames: []
        )

        XCTAssertNil(AnchorScorer.bestCandidate(in: [first, second], window: window))
    }

    func testHostBuildChangeInvalidatesCachedCandidate() {
        let candidate = AnchorCandidate(
            frame: CGRect(x: 112, y: 92, width: 220, height: 40),
            role: "AXButton",
            childRoles: ["AXImage", "AXStaticText"],
            siblingFrames: []
        )
        var cache = AnchorCache()
        cache.store(candidate, buildIdentity: "build-a")

        XCTAssertEqual(cache.candidate(buildIdentity: "build-a"), candidate)
        XCTAssertNil(cache.candidate(buildIdentity: "build-b"))
        XCTAssertNil(cache.candidate(buildIdentity: "build-a"))
    }
}
