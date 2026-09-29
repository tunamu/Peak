/// Every color token in the design system (docs/DESIGN_SYSTEM.md).
///
/// Views use the `Color` shortcuts in `Color+Peak.swift`; this enum holds the raw values so tests can check them.
public enum PeakPalette {
    // MARK: Background

    public static let canvas = ColorToken(
        "bg.canvas", role: .surface,
        dark: RGBA(hex: 0x202020), light: RGBA(hex: 0xF2F2F7)
    )

    public static let fillControl = ColorToken(
        "fill.control", role: .surface,
        dark: RGBA(hex: 0xFFFFFF, alpha: 0.10), light: RGBA(hex: 0x000000, alpha: 0.06)
    )

    // MARK: Text

    public static let textPrimary = ColorToken(
        "text.primary", role: .text,
        dark: RGBA(hex: 0xFFFFFF), light: RGBA(hex: 0x000000)
    )

    /// Card labels ("Energy Level") and tappable supporting text ("Edit").
    /// The dark default is the design's gray, below 4.5:1 on cards; Increase Contrast lifts it.
    public static let textSecondary = ColorToken(
        "text.secondary", role: .text,
        dark: RGBA(hex: 0x808080), light: RGBA(hex: 0x5E5E63),
        darkHighContrast: RGBA(hex: 0xB0B0B5), lightHighContrast: RGBA(hex: 0x3A3A3C)
    )

    /// Non-essential supporting text ("Weekly Average"). Never used for something tappable.
    public static let textTertiary = ColorToken(
        "text.tertiary", role: .text,
        dark: RGBA(hex: 0x67676A), light: RGBA(hex: 0x6C6C70),
        darkHighContrast: RGBA(hex: 0xA8A8AD), lightHighContrast: RGBA(hex: 0x48484A)
    )

    // MARK: Accents

    /// The design's pure reds are 2.85:1 on a dark glass card; Increase Contrast lifts them (Apple's dark systemRed).
    public static let accentSteps = ColorToken(
        "accent.steps", role: .graphic,
        dark: RGBA(hex: 0xFF0004), light: RGBA(hex: 0xD70015),
        darkHighContrast: RGBA(hex: 0xFF453A)
    )

    public static let accentWater = ColorToken(
        "accent.water", role: .graphic,
        dark: RGBA(hex: 0x00BBFF), light: RGBA(hex: 0x0077CC)
    )

    public static let energyReady = ColorToken(
        "energy.ready", role: .graphic,
        dark: RGBA(hex: 0x0DFF00), light: RGBA(hex: 0x1E9E32)
    )

    public static let energyLow = ColorToken(
        "energy.low", role: .graphic,
        dark: RGBA(hex: 0xFFAE00), light: RGBA(hex: 0xB86E00)
    )

    public static let energyNotReady = ColorToken(
        "energy.notReady", role: .graphic,
        dark: RGBA(hex: 0xFF0000), light: RGBA(hex: 0xD70015),
        darkHighContrast: RGBA(hex: 0xFF453A)
    )

    // MARK: Glass tints

    public static let tintPositive = ColorToken(
        "tint.positive", role: .surface,
        dark: RGBA(hex: 0x00FF1A, alpha: 0.10), light: RGBA(hex: 0x1E9E32, alpha: 0.12)
    )

    public static let tintDestructive = ColorToken(
        "tint.destructive", role: .surface,
        dark: RGBA(hex: 0xFF0000, alpha: 0.10), light: RGBA(hex: 0xD70015, alpha: 0.12)
    )

    // MARK: Brand

    public static let brandFlag = ColorToken(
        "brand.flag", role: .brand,
        dark: RGBA(hex: 0xFE0000), light: RGBA(hex: 0xFE0000)
    )

    public static let all: [ColorToken] = [
        canvas, fillControl,
        textPrimary, textSecondary, textTertiary,
        accentSteps, accentWater, energyReady, energyLow, energyNotReady,
        tintPositive, tintDestructive,
        brandFlag,
    ]

    /// What a regular glass card looks like over the canvas, used only by the contrast checks.
    /// Measured on the iOS 27 simulator (F1-02): `.glassEffect(.regular)` card over `bg.canvas`.
    public static let glassSurface = ColorToken(
        "measured.glassSurface", role: .surface,
        dark: RGBA(hex: 0x3A3A3A), light: RGBA(hex: 0xF8F8FD)
    )
}
