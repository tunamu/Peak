import SwiftUI

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

extension Color {
    /// A color that follows light/dark mode and Increase Contrast by itself.
    public init(_ token: ColorToken) {
        #if canImport(UIKit)
            self.init(
                uiColor: UIColor { traits in
                    let value = token.resolve(
                        isDark: traits.userInterfaceStyle == .dark,
                        highContrast: traits.accessibilityContrast == .high
                    )
                    return UIColor(red: value.red, green: value.green, blue: value.blue, alpha: value.alpha)
                }
            )
        #elseif canImport(AppKit)
            // Only for building and testing the package on a Mac host.
            self.init(
                nsColor: NSColor(name: nil) { appearance in
                    let match = appearance.bestMatch(from: [
                        .aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua,
                    ])
                    let value = token.resolve(
                        isDark: match == .darkAqua || match == .accessibilityHighContrastDarkAqua,
                        highContrast: match == .accessibilityHighContrastAqua
                            || match == .accessibilityHighContrastDarkAqua
                    )
                    return NSColor(
                        srgbRed: value.red, green: value.green, blue: value.blue, alpha: value.alpha
                    )
                }
            )
        #endif
    }
}

// Shortcuts so views can write `.foregroundStyle(.peakTextSecondary)`, like the built-in `.secondary`.
extension ShapeStyle where Self == Color {
    public static var peakCanvas: Color { Color(PeakPalette.canvas) }
    public static var peakFillControl: Color { Color(PeakPalette.fillControl) }

    public static var peakTextPrimary: Color { Color(PeakPalette.textPrimary) }
    public static var peakTextSecondary: Color { Color(PeakPalette.textSecondary) }
    public static var peakTextTertiary: Color { Color(PeakPalette.textTertiary) }

    public static var peakSteps: Color { Color(PeakPalette.accentSteps) }
    public static var peakWater: Color { Color(PeakPalette.accentWater) }
    public static var peakEnergyReady: Color { Color(PeakPalette.energyReady) }
    public static var peakEnergyLow: Color { Color(PeakPalette.energyLow) }
    public static var peakEnergyNotReady: Color { Color(PeakPalette.energyNotReady) }

    public static var peakTintPositive: Color { Color(PeakPalette.tintPositive) }
    public static var peakTintDestructive: Color { Color(PeakPalette.tintDestructive) }

    public static var peakBrandFlag: Color { Color(PeakPalette.brandFlag) }
}
