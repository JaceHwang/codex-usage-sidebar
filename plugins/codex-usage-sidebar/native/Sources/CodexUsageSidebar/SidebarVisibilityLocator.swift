@preconcurrency import ApplicationServices
import CoreGraphics
import Foundation
import SidebarCore

@MainActor
final class SidebarVisibilityLocator {
    private struct QueueEntry {
        let element: AXUIElement
        let depth: Int
    }

    private struct ScanResult {
        let matches: [(element: AXUIElement, placement: OverlayPlacement)]
        let visitedCount: Int
        let buttonCandidates: [SidebarToggleCandidate]
        let rendererRootObserved: Bool
        let candidatePhaseOutcome: SidebarChromeCandidatePhaseOutcome
        let rendererTraversalOutcome: SidebarChromeTraversalOutcome?
        let probe: SidebarChromeProbe
    }

    private var lastScanSummary = "sidebar_scan=not-run"
    private let maximumCandidateDepth = 18
    private let maximumDepth = 64
    private let maximumElements = 2_000
    private(set) var rightTitlebarControlsLeadingEdge: CGFloat?

    func placement(
        for processIdentifier: pid_t,
        windowFrame: CGRect
    ) -> OverlayPlacement? {
        guard case let .resolved(placement) = probe(
            for: processIdentifier,
            windowFrame: windowFrame
        ) else {
            return nil
        }
        return placement
    }

    func probe(
        for processIdentifier: pid_t,
        windowFrame: CGRect
    ) -> SidebarChromeProbe {
        guard AXIsProcessTrusted() else {
            lastScanSummary = "sidebar_scan=unavailable:accessibility"
            return .unavailable
        }

        let application = AXUIElementCreateApplication(processIdentifier)
        enableRendererAccessibility(for: application)

        guard let window = windowElement(
            for: application,
            matching: windowFrame
        ) else {
            lastScanSummary = "sidebar_scan=unavailable:window-match"
            return .unavailable
        }

        let scan = toggleMatches(in: window, windowFrame: windowFrame)
        let observedRightTitlebarControlsLeadingEdge =
            TitlebarControlResolver.leadingEdge(
                candidates: scan.buttonCandidates,
                windowFrame: windowFrame
            )
        lastScanSummary = scanSummary(for: scan)
        switch scan.probe {
        case .resolved:
            rightTitlebarControlsLeadingEdge =
                observedRightTitlebarControlsLeadingEdge
        case .unresolved:
            invalidate()
        case .skipped, .unavailable:
            break
        }
        return scan.probe
    }

    func diagnosticDetail(
        for processIdentifier: pid_t,
        windowFrame: CGRect
    ) -> String {
        invalidate()
        let observedPlacement = placement(
            for: processIdentifier,
            windowFrame: windowFrame
        )
        return "sidebar_probe=\(observedPlacement?.rawValue ?? "unknown") " +
            lastScanSummary
    }

    func invalidate() {
        // Placements are deliberately re-scanned. Electron can retain an old
        // toggle description while the left navigation tree has already
        // changed, so caching the toggle element would make placement stale.
        rightTitlebarControlsLeadingEdge = nil
    }

    private func toggleMatches(
        in window: AXUIElement,
        windowFrame: CGRect
    ) -> ScanResult {
        guard let rootChildren = children(of: window) else {
            return ScanResult(
                matches: [],
                visitedCount: 0,
                buttonCandidates: [],
                rendererRootObserved: false,
                candidatePhaseOutcome: .childReadFailed,
                rendererTraversalOutcome: nil,
                probe: .unavailable
            )
        }
        var queue = rootChildren.map {
            QueueEntry(element: $0, depth: 1)
        }
        var index = 0
        var visited = 0
        var matches: [(element: AXUIElement, placement: OverlayPlacement)] = []
        var buttonCandidates: [SidebarToggleCandidate] = []
        var rendererRootObserved = false
        var candidatePhaseOutcome =
            SidebarChromeCandidatePhaseOutcome.complete

        while
            index < queue.count,
            queue[index].depth <= maximumCandidateDepth
        {
            guard visited < maximumElements else {
                candidatePhaseOutcome = .elementLimitReached
                break
            }
            let entry = queue[index]
            index += 1
            visited += 1

            rendererRootObserved = rendererRootObserved ||
                role(of: entry.element) == "AXWebArea"
            if let candidate = candidate(for: entry.element) {
                buttonCandidates.append(candidate)
                if let placement = SidebarToggleResolver.placement(
                    candidates: [candidate],
                    windowFrame: windowFrame
                ) {
                    matches.append((entry.element, placement))
                }
            }

            guard let childElements = children(of: entry.element) else {
                candidatePhaseOutcome = .childReadFailed
                break
            }
            queue.append(
                contentsOf: childElements.map {
                    QueueEntry(element: $0, depth: entry.depth + 1)
                }
            )
        }

        let placement = SidebarToggleResolver.placement(
            candidates: buttonCandidates,
            windowFrame: windowFrame
        )
        let continuation = SidebarChromeScanClassifier.continuation(
            candidatePhaseOutcome: candidatePhaseOutcome,
            resolvedPlacement: placement
        )
        if case let .finish(probe) = continuation {
            return ScanResult(
                matches: matches,
                visitedCount: visited,
                buttonCandidates: buttonCandidates,
                rendererRootObserved: rendererRootObserved,
                candidatePhaseOutcome: candidatePhaseOutcome,
                rendererTraversalOutcome: nil,
                probe: probe
            )
        }

        var rendererTraversalOutcome =
            SidebarChromeTraversalOutcome.complete
        while index < queue.count {
            guard visited < maximumElements else {
                rendererTraversalOutcome = .elementLimitReached
                break
            }
            let entry = queue[index]
            index += 1
            visited += 1

            rendererRootObserved = rendererRootObserved ||
                role(of: entry.element) == "AXWebArea"
            guard let childElements = children(of: entry.element) else {
                rendererTraversalOutcome = .childReadFailed
                break
            }
            guard entry.depth < maximumDepth || childElements.isEmpty else {
                rendererTraversalOutcome = .depthLimitReached
                break
            }
            queue.append(
                contentsOf: childElements.map {
                    QueueEntry(element: $0, depth: entry.depth + 1)
                }
            )
        }
        let probe = SidebarChromeScanClassifier.probeAfterRendererTraversal(
            rendererRootObserved: rendererRootObserved,
            traversalOutcome: rendererTraversalOutcome
        )
        return ScanResult(
            matches: matches,
            visitedCount: visited,
            buttonCandidates: buttonCandidates,
            rendererRootObserved: rendererRootObserved,
            candidatePhaseOutcome: candidatePhaseOutcome,
            rendererTraversalOutcome: rendererTraversalOutcome,
            probe: probe
        )
    }

    private func scanSummary(for scan: ScanResult) -> String {
        let candidateStatus = switch scan.candidatePhaseOutcome {
        case .complete: "complete"
        case .elementLimitReached: "element-limit"
        case .childReadFailed: "child-read-failed"
        }
        let rendererStatus = switch scan.rendererTraversalOutcome {
        case nil: "not-requested"
        case .complete: "complete"
        case .depthLimitReached: "depth-limit"
        case .elementLimitReached: "element-limit"
        case .childReadFailed: "child-read-failed"
        }
        let items = scan.buttonCandidates.map { candidate in
            let description = candidate.description?
                .replacingOccurrences(of: " ", with: "_") ?? "-"
            return "\(description)@\(Int(candidate.frame.midX))," +
                "\(Int(candidate.frame.midY))"
        }.joined(separator: ";")
        return "sidebar_scan=visited:\(scan.visitedCount)," +
            "buttons:\(scan.buttonCandidates.count)," +
            "matches:\(scan.matches.count)," +
            "renderer_root:\(scan.rendererRootObserved ? "yes" : "no")," +
            "candidate_phase:\(candidateStatus)," +
            "renderer_traversal:\(rendererStatus)," +
            "items:\(items)"
    }

    private func candidate(
        for element: AXUIElement
    ) -> SidebarToggleCandidate? {
        guard
            let role: String = attribute(
                element,
                name: kAXRoleAttribute as CFString
            ),
            role == "AXButton",
            let topLeftFrame = frame(of: element)
        else {
            return nil
        }

        let description: String? = attribute(
            element,
            name: kAXDescriptionAttribute as CFString
        )
        return SidebarToggleCandidate(
            frame: appKitFrame(fromTopLeftFrame: topLeftFrame),
            role: role,
            description: description
        )
    }

    private func enableRendererAccessibility(for application: AXUIElement) {
        _ = AXUIElementSetAttributeValue(
            application,
            "AXManualAccessibility" as CFString,
            kCFBooleanTrue
        )
        _ = AXUIElementSetAttributeValue(
            application,
            "AXEnhancedUserInterface" as CFString,
            kCFBooleanTrue
        )
    }

    private func windowElement(
        for application: AXUIElement,
        matching expectedFrame: CGRect
    ) -> AXUIElement? {
        var windows = elementsAttribute(
            application,
            name: kAXWindowsAttribute as CFString
        ).filter {
            role(of: $0) == "AXWindow"
        }
        if
            windows.isEmpty,
            let focused = elementAttribute(
                application,
                name: kAXFocusedWindowAttribute as CFString
            ),
            role(of: focused) == "AXWindow"
        {
            windows = [focused]
        }
        let frames = windows.compactMap { window in
            frame(of: window).map(appKitFrame(fromTopLeftFrame:))
        }
        guard frames.count == windows.count else {
            return nil
        }
        guard let index = SidebarWindowMatcher.bestMatchIndex(
            windowFrames: frames,
            expectedFrame: expectedFrame
        ) else {
            return nil
        }
        return windows[index]
    }

    private func role(of element: AXUIElement) -> String? {
        attribute(element, name: kAXRoleAttribute as CFString)
    }

    private func children(of element: AXUIElement) -> [AXUIElement]? {
        optionalElementsAttribute(
            element,
            name: kAXChildrenAttribute as CFString
        )
    }

    private func elementsAttribute(
        _ element: AXUIElement,
        name: CFString
    ) -> [AXUIElement] {
        optionalElementsAttribute(element, name: name) ?? []
    }

    private func optionalElementsAttribute(
        _ element: AXUIElement,
        name: CFString
    ) -> [AXUIElement]? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, name, &value)
        if error == .noValue || error == .attributeUnsupported {
            return []
        }
        guard error == .success,
            let value,
            CFGetTypeID(value) == CFArrayGetTypeID()
        else {
            return nil
        }
        let array = unsafeDowncast(value, to: CFArray.self)
        var elements: [AXUIElement] = []
        for index in 0..<CFArrayGetCount(array) {
            guard let pointer = CFArrayGetValueAtIndex(array, index) else {
                return nil
            }
            let item = Unmanaged<AnyObject>
                .fromOpaque(pointer)
                .takeUnretainedValue()
            guard CFGetTypeID(item) == AXUIElementGetTypeID() else {
                return nil
            }
            elements.append(unsafeDowncast(item, to: AXUIElement.self))
        }
        return elements
    }

    private func frame(of element: AXUIElement) -> CGRect? {
        guard
            let position = axValueAttribute(
                element,
                name: kAXPositionAttribute as CFString
            ),
            let size = axValueAttribute(
                element,
                name: kAXSizeAttribute as CFString
            ),
            AXValueGetType(position) == .cgPoint,
            AXValueGetType(size) == .cgSize
        else {
            return nil
        }

        var point = CGPoint.zero
        var dimensions = CGSize.zero
        guard
            AXValueGetValue(position, .cgPoint, &point),
            AXValueGetValue(size, .cgSize, &dimensions)
        else {
            return nil
        }
        return CGRect(origin: point, size: dimensions)
    }

    private func axValueAttribute(
        _ element: AXUIElement,
        name: CFString
    ) -> AXValue? {
        var value: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(element, name, &value) == .success,
            let value,
            CFGetTypeID(value) == AXValueGetTypeID()
        else {
            return nil
        }
        return unsafeDowncast(value, to: AXValue.self)
    }

    private func attribute<T>(
        _ element: AXUIElement,
        name: CFString
    ) -> T? {
        var value: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(element, name, &value) == .success,
            let value
        else {
            return nil
        }
        return value as? T
    }

    private func elementAttribute(
        _ element: AXUIElement,
        name: CFString
    ) -> AXUIElement? {
        var value: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(element, name, &value) == .success,
            let value,
            CFGetTypeID(value) == AXUIElementGetTypeID()
        else {
            return nil
        }
        return unsafeDowncast(value, to: AXUIElement.self)
    }

    private func appKitFrame(fromTopLeftFrame frame: CGRect) -> CGRect {
        let primaryDisplayHeight = CGDisplayBounds(CGMainDisplayID()).height
        return CGRect(
            x: frame.minX,
            y: primaryDisplayHeight - frame.maxY,
            width: frame.width,
            height: frame.height
        )
    }
}
