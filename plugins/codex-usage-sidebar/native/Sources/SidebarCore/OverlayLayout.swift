import CoreGraphics
import Foundation

public enum OverlayPlacement: String, Equatable, Sendable {
    case sidebar
    case titlebar
}

public enum OverlayLayout {
    public static let toolbarHeight: CGFloat = 46
    public static let indicatorWidth: CGFloat = 148
    public static let profileIdentityReservation: CGFloat = 112

    public static func sidebarRowFrame(in windowFrame: CGRect) -> CGRect {
        let sidebarMaximum = min(520, windowFrame.width - 320)
        let sidebarWidth = max(240, min(275, sidebarMaximum))
        return CGRect(
            x: windowFrame.minX + 8,
            y: windowFrame.minY,
            width: max(44, sidebarWidth - 16),
            height: toolbarHeight
        )
    }

    public static func sidebarIndicatorFrame(in rowFrame: CGRect) -> CGRect {
        let desiredWidth = min(indicatorWidth, max(86, rowFrame.width * 0.64))
        let minimumX = rowFrame.minX + min(
            profileIdentityReservation,
            rowFrame.width * 0.48
        )
        let originX = max(minimumX, rowFrame.maxX - desiredWidth)
        return CGRect(
            x: originX,
            y: rowFrame.minY,
            width: max(44, rowFrame.maxX - originX),
            height: rowFrame.height
        )
    }

    public static func titlebarIndicatorFrame(
        in windowFrame: CGRect,
        rightControlsLeadingEdge: CGFloat?
    ) -> CGRect {
        let resolvedTrailingEdge = rightControlsLeadingEdge.map { $0 - 8 }
            ?? windowFrame.maxX - 176
        let originX = max(
            windowFrame.minX + 8,
            min(
                resolvedTrailingEdge - indicatorWidth,
                windowFrame.maxX - indicatorWidth - 8
            )
        )
        return CGRect(
            x: originX,
            y: windowFrame.maxY - toolbarHeight,
            width: indicatorWidth,
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

    public static func indicatorFrame(
        in windowFrame: CGRect,
        placement: OverlayPlacement
    ) -> CGRect {
        switch placement {
        case .sidebar:
            sidebarIndicatorFrame(in: sidebarRowFrame(in: windowFrame))
        case .titlebar:
            titlebarIndicatorFrame(
                in: windowFrame,
                rightControlsLeadingEdge: nil
            )
        }
    }
}
