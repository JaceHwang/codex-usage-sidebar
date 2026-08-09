import Foundation

public struct QuotaColorComponents: Equatable, Sendable {
    public let hue: Double
    public let saturation: Double
    public let brightness: Double

    public init(hue: Double, saturation: Double, brightness: Double) {
        self.hue = hue
        self.saturation = saturation
        self.brightness = brightness
    }
}

public enum QuotaColorScale {
    private static let green = QuotaColorComponents(
        hue: 0.36,
        saturation: 0.78,
        brightness: 0.82
    )
    private static let orange = QuotaColorComponents(
        hue: 0.078,
        saturation: 0.96,
        brightness: 1
    )
    private static let red = QuotaColorComponents(
        hue: 0,
        saturation: 0.86,
        brightness: 1
    )
    private static let criticalRed = QuotaColorComponents(
        hue: 0,
        saturation: 0.96,
        brightness: 0.76
    )

    public static func components(
        remainingPercent: Int
    ) -> QuotaColorComponents {
        let value = Double(min(100, max(0, remainingPercent)))
        if value >= 40 {
            return interpolate(
                from: orange,
                to: green,
                progress: (value - 40) / 60
            )
        }
        if value >= 20 {
            return interpolate(
                from: red,
                to: orange,
                progress: (value - 20) / 20
            )
        }
        return interpolate(
            from: criticalRed,
            to: red,
            progress: value / 20
        )
    }

    private static func interpolate(
        from start: QuotaColorComponents,
        to end: QuotaColorComponents,
        progress: Double
    ) -> QuotaColorComponents {
        let amount = min(1, max(0, progress))
        return QuotaColorComponents(
            hue: start.hue + (end.hue - start.hue) * amount,
            saturation: start.saturation +
                (end.saturation - start.saturation) * amount,
            brightness: start.brightness +
                (end.brightness - start.brightness) * amount
        )
    }
}
