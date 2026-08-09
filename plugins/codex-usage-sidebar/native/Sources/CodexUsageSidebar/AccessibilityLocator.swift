@preconcurrency import ApplicationServices
import CoreGraphics
import Foundation

@MainActor
final class AccessibilityLocator {
    func isTrusted(prompt: Bool) -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
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
        return quartzFrame.map(appKitFrame(fromTopLeftFrame:))
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
