import CoreGraphics
import Foundation

public enum TitlebarControlResolver {
    public static func leadingEdge(
        candidates: [SidebarToggleCandidate],
        windowFrame: CGRect
    ) -> CGFloat? {
        let toolbarMinimumY = windowFrame.maxY - OverlayLayout.toolbarHeight
        let rightQuarterMinimumX = windowFrame.minX + windowFrame.width * 0.75

        return candidates.filter { candidate in
            candidate.frame.width <= 120
                && candidate.frame.height <= OverlayLayout.toolbarHeight
                && candidate.frame.midY >= toolbarMinimumY
                && candidate.frame.midY <= windowFrame.maxY
                && candidate.frame.midX >= rightQuarterMinimumX
                && candidate.frame.midX <= windowFrame.maxX
        }.map(\.frame.minX).min()
    }
}
