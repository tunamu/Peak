import Foundation

/// A platform-independent sRGB color value.
///
/// Tokens are stored as plain numbers so the same values can be turned into a SwiftUI `Color` and checked for
/// contrast in unit tests.
public struct RGBA: Sendable, Hashable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Creates a color from a `0xRRGGBB` literal, as written in the design file.
    public init(hex: UInt32, alpha: Double = 1) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

    /// The color after drawing it with its alpha over an opaque `background`.
    public func composited(over background: RGBA) -> RGBA {
        RGBA(
            red: red * alpha + background.red * (1 - alpha),
            green: green * alpha + background.green * (1 - alpha),
            blue: blue * alpha + background.blue * (1 - alpha)
        )
    }

    /// WCAG 2.x relative luminance of the opaque color.
    public var relativeLuminance: Double {
        func linear(_ channel: Double) -> Double {
            channel <= 0.040_45 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// WCAG 2.x contrast ratio (1...21) of this color drawn over `background`.
    public func contrastRatio(on background: RGBA) -> Double {
        let foreground = composited(over: background).relativeLuminance
        let back = background.relativeLuminance
        return (max(foreground, back) + 0.05) / (min(foreground, back) + 0.05)
    }
}
