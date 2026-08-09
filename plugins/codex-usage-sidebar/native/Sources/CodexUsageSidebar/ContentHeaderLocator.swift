@preconcurrency import ApplicationServices
import CoreGraphics
import Foundation
import SidebarCore

@MainActor
final class ContentHeaderLocator {
    private struct QueueEntry {
        let element: AXUIElement
        let depth: Int
    }

    private struct ScannedControl {
        let element: AXUIElement
        let value: ContentHeaderControl
    }

    private struct ScannedPane {
        let element: AXUIElement
        let frame: CGRect
    }

    private struct CachedAnchor {
        let processIdentifier: pid_t
        let window: AXUIElement
        let element: AXUIElement
        let source: ContentHeaderAnchorSource
        let expiresAt: Date
    }

    private let maximumDepth = 32
    private let maximumElements = 1_000
    private let cacheLifetime: TimeInterval = 0.75
    private var cachedAnchor: CachedAnchor?
    private(set) var latestDiagnosticDetail = "anchor_scan=not-run"

    func resolve(
        for processIdentifier: pid_t,
        windowFrame: CGRect
    ) -> ContentHeaderAnchor {
        guard AXIsProcessTrusted() else {
            latestDiagnosticDetail = "anchor_scan=accessibility-required"
            return ContentHeaderAnchor(trailingEdge: nil, source: .fallback)
        }

        let application = AXUIElementCreateApplication(processIdentifier)
        enableRendererAccessibility(for: application)
        guard let window = windowElement(
            for: application,
            matching: windowFrame
        ) else {
            latestDiagnosticDetail = "anchor_scan=window-unavailable"
            return ContentHeaderAnchor(trailingEdge: nil, source: .fallback)
        }

        if let anchor = resolvedCachedAnchor(
            processIdentifier: processIdentifier,
            window: window,
            windowFrame: windowFrame
        ) {
            let edge = anchor.trailingEdge.map { String(Int($0)) }
                ?? "fallback"
            latestDiagnosticDetail =
                "anchor_scan=visited:0,controls:0,panes:0," +
                "cached:true,source:\(anchor.source.rawValue),edge:\(edge)"
            return anchor
        }
        cachedAnchor = nil

        let scan = scanLayout(in: window, windowFrame: windowFrame)
        let anchor = ContentHeaderAnchorResolver.resolve(
            controls: scan.controls.map(\.value),
            paneFrames: scan.panes.map(\.frame),
            windowFrame: windowFrame
        )
        if let selected = selectedElement(for: anchor, in: scan) {
            cachedAnchor = CachedAnchor(
                processIdentifier: processIdentifier,
                window: window,
                element: selected,
                source: anchor.source,
                expiresAt: Date().addingTimeInterval(cacheLifetime)
            )
        }
        let edge = anchor.trailingEdge.map { String(Int($0)) } ?? "fallback"
        latestDiagnosticDetail =
            "anchor_scan=visited:\(scan.visited)," +
            "controls:\(scan.controls.count),panes:\(scan.panes.count)," +
            "cached:false,source:\(anchor.source.rawValue),edge:\(edge)"
        return anchor
    }

    private func scanLayout(
        in window: AXUIElement,
        windowFrame: CGRect
    ) -> (controls: [ScannedControl], panes: [ScannedPane], visited: Int) {
        var queue = children(of: window).map {
            QueueEntry(element: $0, depth: 1)
        }
        var index = 0
        var visited = 0
        var controls: [ScannedControl] = []
        var panes: [ScannedPane] = []

        while index < queue.count, visited < maximumElements {
            let entry = queue[index]
            index += 1
            visited += 1

            if
                let role: String = attribute(
                    entry.element,
                    name: kAXRoleAttribute as CFString
                ),
                let topLeftFrame = frame(of: entry.element)
            {
                let appKitFrame = appKitFrame(fromTopLeftFrame: topLeftFrame)
                if role == "AXButton" {
                    if let control = control(
                        for: entry.element,
                        appKitFrame: appKitFrame
                    ) {
                        controls.append(
                            ScannedControl(
                                element: entry.element,
                                value: control
                            )
                        )
                    }
                } else if role == "AXGroup" {
                    panes.append(
                        ScannedPane(element: entry.element, frame: appKitFrame)
                    )
                }
            }

            if entry.depth < maximumDepth {
                let rightSideChildren = children(of: entry.element).filter {
                    guard let topLeftFrame = frame(of: $0) else {
                        return true
                    }
                    return appKitFrame(
                        fromTopLeftFrame: topLeftFrame
                    ).maxX >= windowFrame.midX
                }
                queue.append(
                    contentsOf: rightSideChildren.map {
                        QueueEntry(element: $0, depth: entry.depth + 1)
                    }
                )
            }
        }
        return (controls, panes, visited)
    }

    private func resolvedCachedAnchor(
        processIdentifier: pid_t,
        window: AXUIElement,
        windowFrame: CGRect
    ) -> ContentHeaderAnchor? {
        guard
            let cachedAnchor,
            cachedAnchor.processIdentifier == processIdentifier,
            CFEqual(cachedAnchor.window, window),
            cachedAnchor.expiresAt > Date()
        else {
            return nil
        }

        let anchor: ContentHeaderAnchor
        switch cachedAnchor.source {
        case .openLocation, .labeledControl:
            guard let control = control(for: cachedAnchor.element) else {
                return nil
            }
            anchor = ContentHeaderAnchorResolver.resolve(
                controls: [control],
                paneFrames: [],
                windowFrame: windowFrame
            )
        case .rightPaneBoundary:
            guard let topLeftFrame = frame(of: cachedAnchor.element) else {
                return nil
            }
            anchor = ContentHeaderAnchorResolver.resolve(
                controls: [],
                paneFrames: [appKitFrame(fromTopLeftFrame: topLeftFrame)],
                windowFrame: windowFrame
            )
        case .fallback:
            return nil
        }
        return anchor.source == cachedAnchor.source ? anchor : nil
    }

    private func selectedElement(
        for anchor: ContentHeaderAnchor,
        in scan: (controls: [ScannedControl], panes: [ScannedPane], visited: Int)
    ) -> AXUIElement? {
        guard let edge = anchor.trailingEdge else {
            return nil
        }
        switch anchor.source {
        case .openLocation, .labeledControl:
            return scan.controls.first {
                abs($0.value.frame.minX - edge) < 0.5
            }?.element
        case .rightPaneBoundary:
            return scan.panes.first {
                abs($0.frame.minX - edge) < 0.5
            }?.element
        case .fallback:
            return nil
        }
    }

    private func control(
        for element: AXUIElement,
        appKitFrame suppliedFrame: CGRect? = nil
    ) -> ContentHeaderControl? {
        let resolvedFrame: CGRect
        if let suppliedFrame {
            resolvedFrame = suppliedFrame
        } else if let topLeftFrame = frame(of: element) {
            resolvedFrame = appKitFrame(fromTopLeftFrame: topLeftFrame)
        } else {
            return nil
        }
        let labels = [
            kAXTitleAttribute,
            kAXDescriptionAttribute,
            kAXHelpAttribute,
            kAXIdentifierAttribute,
        ].compactMap { name in
            attribute(element, name: name as CFString) as String?
        }
        return ContentHeaderControl(frame: resolvedFrame, labels: labels)
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
        guard let index = WindowFrameMatcher.bestMatchIndex(
            windowFrames: frames,
            expectedFrame: expectedFrame
        ) else {
            return nil
        }
        return windows[index]
    }

    private func children(of element: AXUIElement) -> [AXUIElement] {
        elementsAttribute(element, name: kAXChildrenAttribute as CFString)
    }

    private func elementsAttribute(
        _ element: AXUIElement,
        name: CFString
    ) -> [AXUIElement] {
        var value: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(element, name, &value) == .success,
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
            )
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
