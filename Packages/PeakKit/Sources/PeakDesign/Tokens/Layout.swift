import CoreGraphics

/// The spacing scale: 4 · 8 · 12 · 16 · 24 · 32, plus the named uses from the design.
public enum Spacing {
    public static let xxSmall: CGFloat = 4
    public static let xSmall: CGFloat = 8
    public static let small: CGFloat = 12
    public static let medium: CGFloat = 16
    public static let large: CGFloat = 24
    public static let xLarge: CGFloat = 32

    /// Leading and trailing screen margin.
    public static let screenMargin: CGFloat = medium
    /// Horizontal padding inside a card.
    public static let cardHorizontal: CGFloat = large
    /// Vertical padding inside a card.
    public static let cardVertical: CGFloat = medium
    /// Gap between sections on a screen.
    public static let section: CGFloat = large
}

/// Corner radii. Pills use `Capsule`; nested corners use `ConcentricRectangle`.
public enum Radius {
    public static let card: CGFloat = 20
    /// Tables and buttons.
    public static let control: CGFloat = 16
}

/// Fixed sizes from the design and the HIG.
public enum Metrics {
    /// Smallest tappable area; smaller rows grow theirs with `contentShape`.
    public static let minTouchTarget: CGFloat = 44
}
