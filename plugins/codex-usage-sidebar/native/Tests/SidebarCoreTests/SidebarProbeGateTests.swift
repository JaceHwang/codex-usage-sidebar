import Foundation
import SidebarCore
import XCTest

final class SidebarProbeGateTests: XCTestCase {
    func testHintSuppressesAccessibilityProbeUntilRendererSettles() {
        let hintTime = Date(timeIntervalSince1970: 1_000)
        var gate = SidebarProbeGate(settlingInterval: 0.35)

        gate.observeHint(at: hintTime)

        XCTAssertFalse(gate.shouldProbe(at: hintTime))
        XCTAssertFalse(
            gate.shouldProbe(
                at: hintTime.addingTimeInterval(0.349)
            )
        )
        XCTAssertTrue(
            gate.shouldProbe(
                at: hintTime.addingTimeInterval(0.35)
            )
        )
    }
}
