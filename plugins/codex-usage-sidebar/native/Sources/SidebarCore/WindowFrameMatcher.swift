import CoreGraphics

public enum WindowFrameMatcher {
    public static func bestMatchIndex(
        windowFrames: [CGRect],
        expectedFrame: CGRect,
        maximumEdgeError: CGFloat = 24
    ) -> Int? {
        windowFrames.enumerated()
            .map { index, frame in
                (index: index, error: edgeError(frame, expectedFrame))
            }
            .filter { $0.error <= maximumEdgeError }
            .min { lhs, rhs in lhs.error < rhs.error }?
            .index
    }

    private static func edgeError(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        max(
            abs(lhs.minX - rhs.minX),
            abs(lhs.minY - rhs.minY),
            abs(lhs.maxX - rhs.maxX),
            abs(lhs.maxY - rhs.maxY)
        )
    }
}
