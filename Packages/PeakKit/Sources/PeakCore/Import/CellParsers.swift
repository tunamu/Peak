import Foundation

/// A set written in one cell: "27.5 x 9", "27,5kg×9", "60 lb * 8", or the `/coach` form "27.5x8:9" (target 8, done 9).
public struct SetCell: Equatable, Sendable {
    public var weight: Double
    public var reps: Int
    public var targetReps: Int?
    /// "kg" or "lb" when the cell says so.
    public var unit: PeakExportV1.WeightUnit?

    public init(weight: Double, reps: Int, targetReps: Int? = nil, unit: PeakExportV1.WeightUnit? = nil) {
        self.weight = weight
        self.reps = reps
        self.targetReps = targetReps
        self.unit = unit
    }

    /// `nil` for anything else. A lone decimal comma or point is read as a decimal in either convention: in a set cell
    /// "27,5" cannot mean anything else.
    public static func parse(_ text: String) -> SetCell? {
        let pattern = #/^\s*(\d+(?:[.,]\d+)?)\s*(kg|lbs|lb)?\s*[x×*]\s*(\d+)(?::(\d+))?\s*$/#.ignoresCase()
        guard let match = text.wholeMatch(of: pattern),
            let weight = Double(match.output.1.replacingOccurrences(of: ",", with: ".")),
            let first = Int(match.output.3)
        else { return nil }
        let unit: PeakExportV1.WeightUnit? = match.output.2.map { $0.lowercased() == "kg" ? .kg : .lb }
        // "27.5x8:9": target 8, done 9.
        if let done = match.output.4.flatMap({ Int($0) }) {
            return SetCell(weight: weight, reps: done, targetReps: first, unit: unit)
        }
        return SetCell(weight: weight, reps: first, unit: unit)
    }

    /// "-", "–" or an empty cell: no set there.
    public static func isEmpty(_ text: String) -> Bool {
        let text = text.trimmingCharacters(in: .whitespaces)
        return text.isEmpty || text == "-" || text == "–" || text == "—"
    }
}

/// The order of day, month and year in dates like "07.09.2026" or "9/7/2026". "2026-09-07" is always year first.
public enum DateOrder: String, CaseIterable, Sendable {
    case dayMonthYear, monthDayYear, yearMonthDay
}

/// A session label: its date, and its number when it has one ("3. Seans (07.09.2026)", "Session 3", "1. Seans").
public struct SessionLabel: Equatable, Sendable {
    public var date: LocalDate?
    public var number: Int?

    /// The first date in the text, read in `order`, and a leading or trailing session number.
    public static func parse(_ text: String, order: DateOrder) -> SessionLabel? {
        let date = DateText.find(in: text).flatMap { $0.date(order: order) }
        let key = text.matchingKey
        // matchingKey folds "gün" to "gun".
        let leading = key.firstMatch(of: #/^#?(\d+)\s*\.?\s*(seans|session|antrenman|workout|gun|day)\b/#)
        let trailing = key.firstMatch(of: #/^(seans|session|antrenman|workout|gun|day)\s*#?(\d+)\b/#)
        let number = leading.flatMap { Int($0.output.1) } ?? trailing.flatMap { Int($0.output.2) }
        guard date != nil || number != nil else { return nil }
        return SessionLabel(date: date, number: number)
    }
}

/// Dates written as text, in any of the usual orders.
public struct DateText: Equatable, Sendable {
    /// The three numbers in the order written: "07.09.2026" is 7, 9, 2026.
    public var first: Int
    public var second: Int
    public var third: Int
    public var yearFirst: Bool

    /// The first thing that looks like a date: "2026-09-07", "07.09.2026", "9/7/26", also inside other text.
    public static func find(in text: String) -> DateText? {
        guard
            let match = text.firstMatch(
                of: #/(?:^|\D)(\d{1,4})[./-](\d{1,2})[./-](\d{1,4})(?!\d)/#),
            let first = Int(match.output.1), let second = Int(match.output.2), let third = Int(match.output.3)
        else { return nil }
        let yearFirst = match.output.1.count == 4
        guard yearFirst || match.output.3.count == 4 || match.output.3.count == 2 else { return nil }
        return DateText(first: first, second: second, third: third, yearFirst: yearFirst)
    }

    public func date(order: DateOrder) -> LocalDate? {
        let year = yearFirst ? first : third
        let month = yearFirst || order == .dayMonthYear ? second : first
        let day = yearFirst ? third : order == .dayMonthYear ? first : second
        let fullYear = year < 100 ? 2_000 + year : year
        return LocalDate(String(format: "%04d-%02d-%02d", fullYear, month, day))
    }

    /// The order that fits every date: a first part above 12 means day first, a second part above 12 means month
    /// first. Without such a date, "." and "-" mean day first (Europe), "/" month first (US), and the guess is
    /// marked unsure so the mapping screen asks.
    public static func detectOrder(in texts: [String]) -> (order: DateOrder, isSure: Bool) {
        var dayFirst = false
        var monthFirst = false
        var slash = false
        for text in texts {
            guard let date = find(in: text), !date.yearFirst else { continue }
            if date.first > 12 { dayFirst = true }
            if date.second > 12 { monthFirst = true }
            if text.contains("/") { slash = true }
        }
        switch (dayFirst, monthFirst) {
        case (true, false): return (.dayMonthYear, true)
        case (false, true): return (.monthDayYear, true)
        case (true, true): return (.dayMonthYear, false)
        case (false, false): return slash ? (.monthDayYear, false) : (.dayMonthYear, true)
        }
    }
}
