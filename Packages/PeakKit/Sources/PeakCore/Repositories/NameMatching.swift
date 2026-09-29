import Foundation

extension String {
    /// A key for matching names regardless of case, accents and surrounding spaces: "İncline Walk" = "incline walk".
    /// Uses a fixed locale so the Turkish dotted İ folds the same on every device.
    public var matchingKey: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
