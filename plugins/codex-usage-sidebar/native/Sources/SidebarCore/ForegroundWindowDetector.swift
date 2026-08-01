import CoreGraphics
import Foundation

public struct WindowOwner: Equatable, Sendable {
    public let processIdentifier: pid_t
    public let layer: Int
    public let frame: CGRect

    public init(
        processIdentifier: pid_t,
        layer: Int,
        frame: CGRect
    ) {
        self.processIdentifier = processIdentifier
        self.layer = layer
        self.frame = frame
    }
}

public enum ForegroundWindowDetector {
    public static func isHostFrontmost(
        hostProcessIdentifier: pid_t,
        orderedWindows: [WindowOwner]
    ) -> Bool {
        orderedWindows.first {
            $0.layer == 0 &&
                $0.frame.width >= 200 &&
                $0.frame.height >= 150
        }?.processIdentifier == hostProcessIdentifier
    }
}
