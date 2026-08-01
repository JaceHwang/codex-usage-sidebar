import SidebarCore
import XCTest

final class OverlayPresentationPolicyTests: XCTestCase {
    func testResolvedMainSurfaceShowsObservedPlacement() {
        XCTAssertEqual(
            OverlayPresentationPolicy.decision(for: .resolved(.sidebar)),
            .show(.sidebar)
        )
        XCTAssertEqual(
            OverlayPresentationPolicy.decision(for: .resolved(.titlebar)),
            .show(.titlebar)
        )
    }

    func testSkippedProbePreservesLastConfirmedPlacement() {
        XCTAssertEqual(
            OverlayPresentationPolicy.decision(for: .skipped),
            .preserve
        )
    }

    func testUnavailableProbePreservesLastConfirmedPlacement() {
        XCTAssertEqual(
            OverlayPresentationPolicy.decision(for: .unavailable),
            .preserve
        )
    }

    func testResolvedChromeStopsBeforeDeepRendererTraversal() {
        XCTAssertEqual(
            SidebarChromeScanClassifier.continuation(
                candidatePhaseOutcome: .complete,
                resolvedPlacement: .sidebar
            ),
            .finish(.resolved(.sidebar))
        )
    }

    func testUnresolvedCandidatePhaseContinuesRendererTraversal() {
        XCTAssertEqual(
            SidebarChromeScanClassifier.continuation(
                candidatePhaseOutcome: .complete,
                resolvedPlacement: nil
            ),
            .continueRendererTraversal
        )
    }

    func testCandidatePhaseFailuresAreUnavailable() {
        let failureOutcomes: [SidebarChromeCandidatePhaseOutcome] = [
            .elementLimitReached,
            .childReadFailed,
        ]

        for outcome in failureOutcomes {
            XCTAssertEqual(
                SidebarChromeScanClassifier.continuation(
                    candidatePhaseOutcome: outcome,
                    resolvedPlacement: .titlebar
                ),
                .finish(.unavailable)
            )
        }
    }

    func testCompletedRendererWithoutMainChromeIsUnresolved() {
        XCTAssertEqual(
            SidebarChromeScanClassifier.probeAfterRendererTraversal(
                rendererRootObserved: true,
                traversalOutcome: .complete
            ),
            .unresolved
        )
    }

    func testIncompleteRendererTraversalIsUnavailable() {
        let incompleteOutcomes: [SidebarChromeTraversalOutcome] = [
            .depthLimitReached,
            .elementLimitReached,
            .childReadFailed,
        ]

        for outcome in incompleteOutcomes {
            XCTAssertEqual(
                SidebarChromeScanClassifier.probeAfterRendererTraversal(
                    rendererRootObserved: true,
                    traversalOutcome: outcome
                ),
                .unavailable
            )
        }
    }

    func testCompletedRendererTraversalWithoutRootIsUnavailable() {
        XCTAssertEqual(
            SidebarChromeScanClassifier.probeAfterRendererTraversal(
                rendererRootObserved: false,
                traversalOutcome: .complete
            ),
            .unavailable
        )
    }

    func testCompletedUnresolvedSurfaceHidesOverlay() {
        XCTAssertEqual(
            OverlayPresentationPolicy.decision(for: .unresolved),
            .hide
        )
    }
}
