@preconcurrency import ApplicationServices
import CoreGraphics
import Foundation
import SidebarCore

@MainActor
final class AccessibilityLocator {
    private struct QueueEntry {
        let element: AXUIElement
        let siblingFrames: [CGRect]
        let depth: Int
    }

    private var cachedProcessIdentifier: pid_t?
    private var cachedElement: AXUIElement?
    private var cachedFrame: CGRect?
    private let maximumDepth = 8
    private let maximumElements = 600

    func profileRow(for processIdentifier: pid_t) -> CGRect? {
        let fallbackWindowFrame = hostWindowFrame(
            for: processIdentifier
        )
        guard requestAccessibilityTrust() else {
            return fallbackWindowFrame.flatMap(geometricProfileRow)
        }

        let application = AXUIElementCreateApplication(processIdentifier)
        enableRendererAccessibility(for: application)
        guard let window = windowElement(for: application) else {
            return fallbackWindowFrame.flatMap(geometricProfileRow)
        }
        guard let windowFrame = frame(of: window) ?? fallbackWindowFrame else {
            return nil
        }

        if
            cachedProcessIdentifier == processIdentifier,
            let cachedElement,
            let verifiedFrame = frame(of: cachedElement),
            verifiedFrame.width >= 90,
            verifiedFrame.height >= 26,
            verifiedFrame.height <= 64,
            windowFrame.contains(verifiedFrame)
        {
            cachedFrame = verifiedFrame
            return appKitFrame(fromTopLeftFrame: verifiedFrame)
        }

        let candidates = candidates(in: window)
        guard let winner = AnchorScorer.bestCandidate(
            in: candidates.map(\.candidate),
            window: windowFrame
        ) else {
            invalidateCachedAnchor()
            return geometricProfileRow(in: windowFrame)
        }
        let winningElement = candidates.first {
            $0.candidate == winner
        }?.element

        cachedProcessIdentifier = processIdentifier
        cachedElement = winningElement
        cachedFrame = winner.frame
        return appKitFrame(fromTopLeftFrame: winner.frame)
    }

    func invalidateCachedAnchor() {
        cachedProcessIdentifier = nil
        cachedElement = nil
        cachedFrame = nil
    }

    func isTrusted(prompt: Bool) -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func diagnosticDetail(for processIdentifier: pid_t) -> String {
        let fallbackWindowFrame = hostWindowFrame(
            for: processIdentifier
        )
        let trusted = isTrusted(prompt: false)
        guard trusted else {
            return fallbackWindowFrame == nil
                ? "anchor_strategy=unavailable"
                : "anchor_strategy=geometric accessibility=required"
        }
        let application = AXUIElementCreateApplication(processIdentifier)
        enableRendererAccessibility(for: application)
        guard let window = windowElement(for: application) else {
            return fallbackWindowFrame == nil
                ? "anchor_strategy=unavailable"
                : "anchor_strategy=geometric ax_window=unavailable"
        }
        guard let windowFrame = frame(of: window) ?? fallbackWindowFrame
        else {
            return "anchor_strategy=unavailable"
        }
        let allCandidates = candidates(in: window).map(\.candidate)
        let semantic = AnchorScorer.bestCandidate(
            in: allCandidates,
            window: windowFrame
        ) != nil
        return semantic
            ? "anchor_strategy=semantic ax_elements=\(allCandidates.count)"
            : "anchor_strategy=geometric ax_elements=\(allCandidates.count)"
    }

    private func requestAccessibilityTrust() -> Bool {
        isTrusted(
            prompt: AccessibilityTrustPolicy.shouldPromptAutomatically
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

    private func geometricProfileRow(in windowFrame: CGRect) -> CGRect? {
        guard windowFrame.width >= 560, windowFrame.height >= 400 else {
            return nil
        }
        return OverlayLayout.sidebarRowFrame(in: windowFrame)
    }

    private func candidates(
        in window: AXUIElement
    ) -> [(candidate: AnchorCandidate, element: AXUIElement)] {
        let rootChildren = children(of: window)
        let rootFrames = rootChildren.compactMap(frame)
        var queue = rootChildren.map {
            QueueEntry(
                element: $0,
                siblingFrames: rootFrames,
                depth: 1
            )
        }
        var index = 0
        var visited = 0
        var result: [(candidate: AnchorCandidate, element: AXUIElement)] = []

        while index < queue.count, visited < maximumElements {
            let entry = queue[index]
            index += 1
            visited += 1

            let directChildren = children(of: entry.element)
            if
                let role: String = attribute(
                    entry.element,
                    name: kAXRoleAttribute as CFString
                ),
                let elementFrame = frame(of: entry.element)
            {
                let childRoles = Set(
                    directChildren.compactMap {
                        attribute(
                            $0,
                            name: kAXRoleAttribute as CFString
                        ) as String?
                    }
                )
                result.append(
                    (
                        candidate: AnchorCandidate(
                        frame: elementFrame,
                        role: role,
                        childRoles: childRoles,
                        siblingFrames: entry.siblingFrames.filter {
                            $0 != elementFrame
                        }
                        ),
                        element: entry.element
                    )
                )
            }

            if entry.depth < maximumDepth, !directChildren.isEmpty {
                let directFrames = directChildren.compactMap(frame)
                queue.append(
                    contentsOf: directChildren.map {
                        QueueEntry(
                            element: $0,
                            siblingFrames: directFrames,
                            depth: entry.depth + 1
                        )
                    }
                )
            }
        }
        return result
    }

    private func children(of element: AXUIElement) -> [AXUIElement] {
        elementsAttribute(
            element,
            name: kAXChildrenAttribute as CFString
        )
    }

    private func elementsAttribute(
        _ element: AXUIElement,
        name: CFString
    ) -> [AXUIElement] {
        var value: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(
                element,
                name,
                &value
            ) == .success,
            let value,
            CFGetTypeID(value) == CFArrayGetTypeID()
        else {
            return []
        }
        let array = unsafeDowncast(value, to: CFArray.self)
        return (0..<CFArrayGetCount(array)).compactMap { index in
            guard let pointer = CFArrayGetValueAtIndex(array, index) else {
                return nil
            }
            let item = Unmanaged<AnyObject>
                .fromOpaque(pointer)
                .takeUnretainedValue()
            guard CFGetTypeID(item) == AXUIElementGetTypeID() else {
                return nil
            }
            return unsafeDowncast(item, to: AXUIElement.self)
        }
    }

    private func windowElement(for application: AXUIElement) -> AXUIElement? {
        if
            let focused = elementAttribute(
                application,
                name: kAXFocusedWindowAttribute as CFString
            ),
            role(of: focused) == "AXWindow"
        {
            return focused
        }
        return elementsAttribute(
            application,
            name: kAXWindowsAttribute as CFString
        ).first {
            role(of: $0) == "AXWindow"
        }
    }

    private func role(of element: AXUIElement) -> String? {
        attribute(element, name: kAXRoleAttribute as CFString)
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

    func hostWindowFrame(for processIdentifier: pid_t) -> CGRect? {
        guard
            let windowInfo = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID
            ) as? [[String: Any]]
        else {
            return nil
        }

        let quartzFrame = windowInfo.compactMap { item -> CGRect? in
            guard
                (item[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value ==
                    processIdentifier,
                (item[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                let bounds = item[kCGWindowBounds as String]
                    as? [String: Any],
                let frame = CGRect(
                    dictionaryRepresentation: bounds as CFDictionary
                ),
                frame.width > 300,
                frame.height > 200
            else {
                return nil
            }
            return frame
        }.max {
            $0.width * $0.height < $1.width * $1.height
        }
        guard let quartzFrame else {
            return nil
        }
        return appKitFrame(fromTopLeftFrame: quartzFrame)
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
}
