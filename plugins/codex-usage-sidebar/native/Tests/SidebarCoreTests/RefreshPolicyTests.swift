import Foundation
import XCTest
@testable import SidebarCore

final class RefreshPolicyTests: XCTestCase {
    private let policy = RefreshPolicy()

    func testForegroundAndBackgroundIntervals() {
        XCTAssertEqual(policy.foregroundInterval, .seconds(1))
        XCTAssertEqual(policy.backgroundInterval, .seconds(5))
        XCTAssertEqual(policy.interval(isHostForeground: true), .seconds(1))
        XCTAssertEqual(policy.interval(isHostForeground: false), .seconds(5))
        XCTAssertEqual(policy.intervalSeconds(isHostForeground: true), 1)
        XCTAssertEqual(policy.intervalSeconds(isHostForeground: false), 5)
    }

    func testStreamRecoveryWaitsTwelveSecondsFromLatestLivenessPoint() {
        let start = Date(timeIntervalSince1970: 1_000)

        XCTAssertFalse(
            policy.shouldRecoverStream(
                lastSnapshotAt: nil,
                clientStartedAt: start,
                now: start.addingTimeInterval(11.999)
            )
        )
        XCTAssertTrue(
            policy.shouldRecoverStream(
                lastSnapshotAt: nil,
                clientStartedAt: start,
                now: start.addingTimeInterval(12)
            )
        )

        let laterSnapshot = start.addingTimeInterval(8)
        XCTAssertFalse(
            policy.shouldRecoverStream(
                lastSnapshotAt: laterSnapshot,
                clientStartedAt: start,
                now: laterSnapshot.addingTimeInterval(11.999)
            )
        )
        XCTAssertTrue(
            policy.shouldRecoverStream(
                lastSnapshotAt: laterSnapshot,
                clientStartedAt: start,
                now: laterSnapshot.addingTimeInterval(12)
            )
        )
    }

    func testFocusRequestsImmediateRefresh() {
        XCTAssertTrue(policy.shouldRefreshImmediately(for: .focus))
        XCTAssertTrue(policy.shouldRefreshImmediately(for: .startup))
        XCTAssertFalse(policy.shouldRefreshImmediately(for: .timer))
        XCTAssertFalse(policy.shouldRefreshImmediately(for: .notification))
    }

    func testResetRefreshAddsTwoSeconds() {
        let reset = Date(timeIntervalSince1970: 1_785_628_824)

        XCTAssertEqual(
            policy.nextResetRefresh(resetsAt: reset),
            reset.addingTimeInterval(2)
        )
    }

    func testStaleDataDimsThenHidesAtFiveMinutes() {
        let received = Date(timeIntervalSince1970: 1_000)

        XCTAssertEqual(
            policy.freshness(receivedAt: received, now: received.addingTimeInterval(119)),
            .fresh
        )
        XCTAssertEqual(
            policy.freshness(receivedAt: received, now: received.addingTimeInterval(120)),
            .dimmed
        )
        XCTAssertEqual(
            policy.freshness(receivedAt: received, now: received.addingTimeInterval(299)),
            .dimmed
        )
        XCTAssertEqual(
            policy.freshness(receivedAt: received, now: received.addingTimeInterval(300)),
            .hidden
        )
    }

    func testHostBuildChangeInvalidatesAnchorAndRestartsClient() {
        XCTAssertEqual(
            policy.actionsForHostTransition(from: "build-a", to: "build-b"),
            HostTransitionActions(invalidateAnchor: true, restartClient: true)
        )
        XCTAssertEqual(
            policy.actionsForHostTransition(from: "build-a", to: "build-a"),
            HostTransitionActions(invalidateAnchor: false, restartClient: false)
        )
    }
}
