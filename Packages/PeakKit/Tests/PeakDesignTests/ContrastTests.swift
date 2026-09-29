import Foundation
import PeakDesign
import Testing

/// WCAG AA checks for the palette (docs/DESIGN_SYSTEM.md › Contrast).
///
/// Every token is checked on the canvas and on the measured glass card, in all four appearances.
@Suite struct ContrastTests {
    struct Appearance: CustomStringConvertible {
        let isDark: Bool
        let highContrast: Bool
        var description: String { (isDark ? "dark" : "light") + (highContrast ? " + high contrast" : "") }
    }

    static let appearances = [
        Appearance(isDark: true, highContrast: false),
        Appearance(isDark: true, highContrast: true),
        Appearance(isDark: false, highContrast: false),
        Appearance(isDark: false, highContrast: true),
    ]

    /// Dark values kept as designed; they pass only with Increase Contrast on (ADR 0017).
    static let darkDesignExceptions: Set = [
        PeakPalette.textSecondary.name, PeakPalette.textTertiary.name,
        PeakPalette.accentSteps.name, PeakPalette.energyNotReady.name,
    ]

    static func isDesignException(_ token: ColorToken, _ appearance: Appearance) -> Bool {
        appearance.isDark && !appearance.highContrast && darkDesignExceptions.contains(token.name)
    }

    static func backgrounds(_ appearance: Appearance) -> [RGBA] {
        let canvas = PeakPalette.canvas.resolve(isDark: appearance.isDark, highContrast: appearance.highContrast)
        let glass = PeakPalette.glassSurface
            .resolve(isDark: appearance.isDark, highContrast: appearance.highContrast)
            .composited(over: canvas)
        return [canvas, glass]
    }

    static func minimumRatio(_ token: ColorToken, _ appearance: Appearance) -> Double {
        let color = token.resolve(isDark: appearance.isDark, highContrast: appearance.highContrast)
        return backgrounds(appearance).map { color.contrastRatio(on: $0) }.min() ?? 0
    }

    @Test(arguments: appearances)
    func textMeetsAA(_ appearance: Appearance) {
        for token in PeakPalette.all where token.role == .text {
            guard !Self.isDesignException(token, appearance) else { continue }
            let ratio = Self.minimumRatio(token, appearance)
            #expect(ratio >= 4.5, "\(token.name) is \(ratio):1 in \(appearance)")
        }
    }

    @Test(arguments: appearances)
    func graphicsMeetAA(_ appearance: Appearance) {
        for token in PeakPalette.all where token.role == .graphic {
            guard !Self.isDesignException(token, appearance) else { continue }
            let ratio = Self.minimumRatio(token, appearance)
            #expect(ratio >= 3, "\(token.name) is \(ratio):1 in \(appearance)")
        }
    }

    @Test func exceptionsHaveHighContrastValues() {
        for token in PeakPalette.all where Self.darkDesignExceptions.contains(token.name) {
            #expect(token.darkHighContrast != nil, "\(token.name) needs a dark high-contrast value")
        }
    }

    @Test(arguments: appearances)
    func secondaryStaysStrongerThanTertiary(_ appearance: Appearance) {
        let secondary = Self.minimumRatio(PeakPalette.textSecondary, appearance)
        let tertiary = Self.minimumRatio(PeakPalette.textTertiary, appearance)
        #expect(secondary > tertiary, "hierarchy lost in \(appearance)")
    }

    /// Prints the table in docs/DESIGN_SYSTEM.md › Contrast. Run `swift test --filter contrastReport` to refresh it.
    @Test func contrastReport() {
        var lines = ["| Token | Dark | Dark + HC | Light | Light + HC |", "| --- | --- | --- | --- | --- |"]
        for token in PeakPalette.all where token.role == .text || token.role == .graphic {
            let cells = Self.appearances.map { String(format: "%.2f", Self.minimumRatio(token, $0)) }
            lines.append("| `\(token.name)` | " + cells.joined(separator: " | ") + " |")
        }
        print(lines.joined(separator: "\n"))
    }
}

@Suite struct RGBATests {
    @Test func parsesHex() {
        let color = RGBA(hex: 0xFF8000)
        #expect(color.red == 1)
        #expect(abs(color.green - 128.0 / 255) < 0.000_1)
        #expect(color.blue == 0)
    }

    @Test func blackOnWhiteIs21() {
        let ratio = RGBA(hex: 0x000000).contrastRatio(on: RGBA(hex: 0xFFFFFF))
        #expect(abs(ratio - 21) < 0.01)
    }

    @Test func compositesAlphaOverBackground() {
        let halfWhite = RGBA(hex: 0xFFFFFF, alpha: 0.5).composited(over: RGBA(hex: 0x000000))
        #expect(abs(halfWhite.red - 0.5) < 0.000_1)
        #expect(halfWhite.alpha == 1)
    }
}
