import CoreGraphics

public enum QuotaDetailSettingsMenuLayout {
    public static let parentSize = CGSize(width: 176, height: 160)
    public static let submenuSize = CGSize(width: 156, height: 120)
    public static let verticalGap: CGFloat = 6
    public static let horizontalGap: CGFloat = 4

    public static func parentFrame(
        settingsButtonFrame: CGRect
    ) -> CGRect {
        CGRect(
            x: settingsButtonFrame.maxX - parentSize.width,
            y: settingsButtonFrame.maxY + verticalGap,
            width: parentSize.width,
            height: parentSize.height
        )
    }

    public static func submenuFrame(
        parentFrame: CGRect,
        visibleFrame: CGRect
    ) -> CGRect {
        let rightFrame = CGRect(
            x: parentFrame.maxX + horizontalGap,
            y: parentFrame.maxY - submenuSize.height,
            width: submenuSize.width,
            height: submenuSize.height
        )
        guard rightFrame.maxX > visibleFrame.maxX else {
            return rightFrame
        }

        let leftFrame = CGRect(
            x: parentFrame.minX - horizontalGap - submenuSize.width,
            y: rightFrame.minY,
            width: submenuSize.width,
            height: submenuSize.height
        )
        guard leftFrame.minX >= visibleFrame.minX else {
            return CGRect(
                x: max(visibleFrame.minX, visibleFrame.maxX - submenuSize.width),
                y: rightFrame.minY,
                width: submenuSize.width,
                height: submenuSize.height
            )
        }
        return leftFrame
    }
}
