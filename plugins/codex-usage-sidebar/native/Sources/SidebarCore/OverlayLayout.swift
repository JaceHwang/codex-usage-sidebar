import CoreGraphics
import Foundation

public enum OverlayLayout {
    public static let toolbarHeight: CGFloat = 46
    public static let indicatorWidth: CGFloat = 164
    public static let maximumIndicatorWidth: CGFloat = 280
    public static let indicatorGap: CGFloat = 8

    public static func indicatorWidth(for measuredLabelWidth: CGFloat) -> CGFloat {
        min(
            maximumIndicatorWidth,
            max(indicatorWidth, ceil(measuredLabelWidth + 44))
        )
    }

    public static func trailingFallbackEdge(
        in windowFrame: CGRect
    ) -> CGFloat {
        windowFrame.maxX - 176 + indicatorGap
    }

    public static func indicatorFrame(
        in windowFrame: CGRect,
        contentTrailingEdge: CGFloat?,
        width: CGFloat = indicatorWidth
    ) -> CGRect {
        let resolvedWidth = max(1, width)
        let resolvedTrailingEdge = contentTrailingEdge.map {
            $0 - indicatorGap
        }
            ?? trailingFallbackEdge(in: windowFrame) - indicatorGap
        let originX = max(
            windowFrame.minX + 8,
            min(
                resolvedTrailingEdge - resolvedWidth,
                windowFrame.maxX - resolvedWidth - 8
            )
        )
        return CGRect(
            x: originX,
            y: windowFrame.maxY - toolbarHeight,
            width: resolvedWidth,
            height: toolbarHeight
        )
    }

    public static func centeredTextFrame(
        in indicatorBounds: CGRect,
        intrinsicHeight: CGFloat,
        horizontalInset: CGFloat
    ) -> CGRect {
        let inset = max(0, min(horizontalInset, indicatorBounds.width / 2))
        let height = max(0, min(intrinsicHeight, indicatorBounds.height))
        return CGRect(
            x: indicatorBounds.minX + inset,
            y: indicatorBounds.midY - height / 2,
            width: max(0, indicatorBounds.width - inset * 2),
            height: height
        )
    }

    public static func controlSurfaceFrame(in indicatorBounds: CGRect) -> CGRect {
        let height = min(30, indicatorBounds.height)
        return CGRect(
            x: indicatorBounds.minX,
            y: indicatorBounds.midY - height / 2,
            width: indicatorBounds.width,
            height: height
        )
    }

}
