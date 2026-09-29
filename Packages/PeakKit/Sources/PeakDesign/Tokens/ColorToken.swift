/// A named color with a value for each appearance the app supports.
///
/// Dark values come from the design. Light values are derived for WCAG AA. The high-contrast values are used when
/// Settings › Accessibility › Increase Contrast is on; when they are `nil` the normal value is kept.
public struct ColorToken: Sendable, Hashable {
    public enum Role: Sendable {
        /// Text and tappable labels: needs 4.5:1.
        case text
        /// Rings, icons, bars and other graphics: needs 3:1.
        case graphic
        /// Backgrounds, fills and glass tints: not checked on their own.
        case surface
        /// Logos: exempt from contrast rules (WCAG 1.4.11).
        case brand
    }

    public let name: String
    public let role: Role
    public let dark: RGBA
    public let light: RGBA
    public let darkHighContrast: RGBA?
    public let lightHighContrast: RGBA?

    public init(
        _ name: String,
        role: Role,
        dark: RGBA,
        light: RGBA,
        darkHighContrast: RGBA? = nil,
        lightHighContrast: RGBA? = nil
    ) {
        self.name = name
        self.role = role
        self.dark = dark
        self.light = light
        self.darkHighContrast = darkHighContrast
        self.lightHighContrast = lightHighContrast
    }

    /// The value for one appearance.
    public func resolve(isDark: Bool, highContrast: Bool) -> RGBA {
        switch (isDark, highContrast) {
        case (true, false): dark
        case (true, true): darkHighContrast ?? dark
        case (false, false): light
        case (false, true): lightHighContrast ?? light
        }
    }
}
