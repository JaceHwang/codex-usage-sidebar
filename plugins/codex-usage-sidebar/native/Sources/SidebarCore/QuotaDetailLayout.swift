import CoreGraphics

public enum QuotaDetailLayout {
    public static let width: CGFloat = 300
    public static let headerHeight: CGFloat = 78
    public static let rowHeight: CGFloat = 24
    public static let verticalPadding: CGFloat = 16
    public static let maximumHeight: CGFloat = 480
    public static let screenMargin: CGFloat = 8
    public static let controlGap: CGFloat = 8

    public static func contentHeight(rowCount: Int) -> CGFloat {
        contentHeight(rowContentHeight: CGFloat(max(0, rowCount)) * rowHeight)
    }

    public static func contentHeight(rowContentHeight: CGFloat) -> CGFloat {
        min(
            maximumHeight,
            headerHeight + verticalPadding + max(0, rowContentHeight)
        )
    }

    public static func frame(
        indicatorFrame: CGRect,
        rowCount: Int,
        visibleFrame: CGRect
    ) -> CGRect {
        frame(
            indicatorFrame: indicatorFrame,
            rowContentHeight: CGFloat(max(0, rowCount)) * rowHeight,
            visibleFrame: visibleFrame
        )
    }

    public static func frame(
        indicatorFrame: CGRect,
        rowContentHeight: CGFloat,
        visibleFrame: CGRect
    ) -> CGRect {
        let availableHeight = max(0, visibleFrame.height - screenMargin * 2)
        let height = min(
            contentHeight(rowContentHeight: rowContentHeight),
            availableHeight
        )
        let minimumX = visibleFrame.minX + screenMargin
        let maximumX = visibleFrame.maxX - width - screenMargin
        let x = min(maximumX, max(minimumX, indicatorFrame.minX))
        let desiredY = indicatorFrame.minY - height - controlGap
        let minimumY = visibleFrame.minY + screenMargin
        let maximumY = visibleFrame.maxY - height - screenMargin
        let y = min(maximumY, max(minimumY, desiredY))

        return CGRect(x: x, y: y, width: width, height: height)
    }

    public static func hoverBridgeFrame(
        indicatorFrame: CGRect,
        detailFrame: CGRect
    ) -> CGRect {
        let minimumX = max(indicatorFrame.minX, detailFrame.minX)
        let maximumX = min(indicatorFrame.maxX, detailFrame.maxX)
        guard maximumX > minimumX else {
            return .null
        }

        if detailFrame.minY >= indicatorFrame.maxY {
            return CGRect(
                x: minimumX,
                y: indicatorFrame.maxY,
                width: maximumX - minimumX,
                height: detailFrame.minY - indicatorFrame.maxY
            )
        }
        if indicatorFrame.minY >= detailFrame.maxY {
            return CGRect(
                x: minimumX,
                y: detailFrame.maxY,
                width: maximumX - minimumX,
                height: indicatorFrame.minY - detailFrame.maxY
            )
        }
        return .null
    }
}
