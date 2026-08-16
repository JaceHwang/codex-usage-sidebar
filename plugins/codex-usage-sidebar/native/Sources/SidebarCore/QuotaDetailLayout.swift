import CoreGraphics

public struct QuotaDetailHeaderFrames: Equatable, Sendable {
    public let title: CGRect
    public let versionBadge: CGRect
    public let remaining: CGRect
    public let progress: CGRect

    public init(
        title: CGRect,
        versionBadge: CGRect,
        remaining: CGRect,
        progress: CGRect
    ) {
        self.title = title
        self.versionBadge = versionBadge
        self.remaining = remaining
        self.progress = progress
    }
}

public struct QuotaDetailInformationFrames: Equatable, Sendable {
    public let topDivider: CGRect
    public let tokenBand: CGRect
    public let rowArea: CGRect
    public let footerDivider: CGRect
    public let footer: CGRect

    public init(
        topDivider: CGRect,
        tokenBand: CGRect,
        rowArea: CGRect,
        footerDivider: CGRect,
        footer: CGRect
    ) {
        self.topDivider = topDivider
        self.tokenBand = tokenBand
        self.rowArea = rowArea
        self.footerDivider = footerDivider
        self.footer = footer
    }
}

public enum QuotaDetailLayout {
    public static let width: CGFloat = 476
    public static let headerHeight: CGFloat = 204
    public static let rowHeight: CGFloat = 40
    public static let verticalPadding: CGFloat = 24
    public static let maximumHeight: CGFloat = 804
    public static let screenMargin: CGFloat = 8
    public static let controlGap: CGFloat = 8
    public static let tokenBandHeight: CGFloat = 250
    public static let tokenBandGap: CGFloat = 12
    public static let tokenBandReservedHeight: CGFloat =
        tokenBandHeight + tokenBandGap * 2
    private static let contentHorizontalInset: CGFloat = 28
    private static let rowTopGap: CGFloat = 20
    private static let footerHeight: CGFloat = 66

    public static func titleWidth(
        intrinsicWidth: CGFloat,
        fittingWidth: CGFloat
    ) -> CGFloat {
        ceil(max(0, max(intrinsicWidth, fittingWidth)))
    }

    public static func headerFrames(
        in bounds: CGRect,
        titleWidth: CGFloat,
        versionBadgeWidth: CGFloat
    ) -> QuotaDetailHeaderFrames {
        let badgeWidth = max(0, versionBadgeWidth)
        let titleX = bounds.minX + 28 + 40 + 18
        let maximumTitleWidth = max(
            0,
            bounds.maxX - contentHorizontalInset - badgeWidth - 8 - titleX
        )
        let title = CGRect(
            x: titleX,
            y: bounds.maxY - 54,
            width: min(max(0, titleWidth), maximumTitleWidth),
            height: 28
        )
        let versionBadge = CGRect(
            x: title.maxX + 8,
            y: title.midY - 14,
            width: badgeWidth,
            height: 28
        )
        let remaining = CGRect(
            x: bounds.minX + contentHorizontalInset,
            y: bounds.maxY - 137,
            width: max(0, bounds.width - contentHorizontalInset * 2),
            height: 42
        )
        let progress = CGRect(
            x: bounds.minX + contentHorizontalInset,
            y: bounds.maxY - 143,
            width: max(0, bounds.width - contentHorizontalInset * 2),
            height: 8
        )
        return QuotaDetailHeaderFrames(
            title: title,
            versionBadge: versionBadge,
            remaining: remaining,
            progress: progress
        )
    }

    public static func informationFrames(
        in bounds: CGRect,
        tokenUsageVisible: Bool = false
    ) -> QuotaDetailInformationFrames {
        let tokenBand: CGRect
        if tokenUsageVisible {
            tokenBand = CGRect(
                x: bounds.minX + contentHorizontalInset,
                y: bounds.maxY - headerHeight - tokenBandGap - tokenBandHeight,
                width: max(0, bounds.width - contentHorizontalInset * 2),
                height: tokenBandHeight
            )
        } else {
            tokenBand = .zero
        }
        return QuotaDetailInformationFrames(
            topDivider: CGRect(
                x: bounds.minX,
                y: bounds.maxY - headerHeight,
                width: bounds.width,
                height: 1
            ),
            tokenBand: tokenBand,
            rowArea: rowAreaFrame(in: bounds, tokenUsageVisible: tokenUsageVisible),
            footerDivider: CGRect(
                x: bounds.minX,
                y: footerFrame(in: bounds).maxY,
                width: bounds.width,
                height: 1
            ),
            footer: footerFrame(in: bounds)
        )
    }

    public static func rowAreaFrame(
        in bounds: CGRect,
        tokenUsageVisible: Bool = false
    ) -> CGRect {
        let informationHeight = headerHeight
        let reservedHeight = informationHeight + (
            tokenUsageVisible ? tokenBandReservedHeight : 0
        ) + footerHeight
        return CGRect(
            x: bounds.minX,
            y: bounds.minY + footerHeight + rowTopGap,
            width: bounds.width,
            height: max(0, bounds.height - rowTopGap - reservedHeight + 8)
        )
    }

    public static func footerFrame(in bounds: CGRect) -> CGRect {
        CGRect(
            x: bounds.minX,
            y: bounds.minY,
            width: bounds.width,
            height: footerHeight
        )
    }

    public static func contentHeight(
        rowCount: Int,
        tokenUsageVisible: Bool = false
    ) -> CGFloat {
        contentHeight(
            rowContentHeight: CGFloat(max(0, rowCount)) * rowHeight,
            tokenUsageVisible: tokenUsageVisible
        )
    }

    public static func contentHeight(
        rowContentHeight: CGFloat,
        tokenUsageVisible: Bool = false
    ) -> CGFloat {
        min(
            maximumHeight,
            headerHeight + verticalPadding + max(0, rowContentHeight) +
                (tokenUsageVisible ? tokenBandReservedHeight : 0) + footerHeight
        )
    }

    public static func frame(
        indicatorFrame: CGRect,
        rowCount: Int,
        visibleFrame: CGRect,
        tokenUsageVisible: Bool = false
    ) -> CGRect {
        frame(
            indicatorFrame: indicatorFrame,
            rowContentHeight: CGFloat(max(0, rowCount)) * rowHeight,
            visibleFrame: visibleFrame,
            tokenUsageVisible: tokenUsageVisible
        )
    }

    public static func frame(
        indicatorFrame: CGRect,
        rowContentHeight: CGFloat,
        visibleFrame: CGRect,
        tokenUsageVisible: Bool = false
    ) -> CGRect {
        let availableHeight = max(0, visibleFrame.height - screenMargin * 2)
        let height = min(
            contentHeight(
                rowContentHeight: rowContentHeight,
                tokenUsageVisible: tokenUsageVisible
            ),
            availableHeight
        )
        let cardWidth = min(
            width,
            max(0, visibleFrame.width - screenMargin * 2)
        )
        let minimumX = visibleFrame.minX + screenMargin
        let maximumX = visibleFrame.maxX - cardWidth - screenMargin
        let x = min(maximumX, max(minimumX, indicatorFrame.minX))
        let desiredY = indicatorFrame.minY - height - controlGap
        let minimumY = visibleFrame.minY + screenMargin
        let maximumY = visibleFrame.maxY - height - screenMargin
        let y = min(maximumY, max(minimumY, desiredY))

        return CGRect(x: x, y: y, width: cardWidth, height: height)
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
