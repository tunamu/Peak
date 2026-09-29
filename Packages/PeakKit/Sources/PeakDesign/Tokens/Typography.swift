import SwiftUI

// Semantic names for the design's type ramp. Each maps to a system text style, so Dynamic Type scales all of them.
// Numbers (durations, tables, steps) also get `.monospacedDigit()` where they are shown.
extension Font {
    /// SF 28 Regular: "Welcome Back", "Settings".
    public static var peakScreenTitle: Font { .title }
    /// SF 22 Regular: "Dashboard", section titles, exercise name.
    public static var peakSectionTitle: Font { .title2 }
    /// SF 20 Semibold: "Chest & Biceps", "02:16".
    public static var peakEmphasis: Font { .title3.weight(.semibold) }
    /// SF 17 Regular: card labels.
    public static var peakCardLabel: Font { .body }
    /// SF 17 Semibold: card values.
    public static var peakCardValue: Font { .headline }
    /// SF 15 Regular: Settings rows.
    public static var peakRow: Font { .subheadline }
    /// SF 13 Regular: table cells, supporting text.
    public static var peakDetail: Font { .footnote }
    /// SF 11 Regular: "5 Movements - 13 Sets", "75%".
    public static var peakMeta: Font { .caption2 }
}
