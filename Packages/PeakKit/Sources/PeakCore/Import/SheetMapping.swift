import Foundation

/// How a sheet lays out its sets (docs/IMPORT_FORMAT.md › Spreadsheets).
public enum SheetLayout: String, CaseIterable, Sendable {
    /// One row per set: Date · Exercise · Set · Weight · Reps.
    case long
    /// One row per session and exercise, sets across: "27.5 x 9" cells or Weight 1 / Reps 1 pairs.
    case wide
    /// The `/coach` history: an exercise name alone on a row, then one row per session ("3. Seans (07.09.2026)")
    /// with set cells.
    case block
}

/// What a column holds (the mapping screen's choices).
public enum ColumnRole: String, CaseIterable, Sendable {
    case date, exercise, setNumber, weight, reps, setCell, workout, note, ignore
}

/// How to read a sheet: found by `SheetAnalyzer`, changed on the mapping screen, applied by `SheetConverter`.
public struct SheetMapping: Equatable, Sendable {
    public var layout: SheetLayout
    /// The row with column names; rows up to it are skipped. Block sheets have none.
    public var headerRow: Int?
    /// One role per column. Several weight and reps columns pair up in order (wide); block sheets ignore roles.
    public var roles: [ColumnRole]
    public var dateOrder: DateOrder
    public var weightUnit: PeakExportV1.WeightUnit
    /// False when the analyzer guessed: the import then shows the mapping screen first.
    public var isConfident: Bool

    public init(
        layout: SheetLayout, headerRow: Int?, roles: [ColumnRole], dateOrder: DateOrder = .dayMonthYear,
        weightUnit: PeakExportV1.WeightUnit = .kg, isConfident: Bool
    ) {
        self.layout = layout
        self.headerRow = headerRow
        self.roles = roles
        self.dateOrder = dateOrder
        self.weightUnit = weightUnit
        self.isConfident = isConfident
    }
}

/// Column names in English and Turkish, compared by `matchingKey` word by word: "Ağırlık (kg)", "Tarih / Seans",
/// "1. Set (Ağırlık x Tekrar)" and "Weight 2" all find their role.
enum HeaderNames {
    static let synonyms: [(ColumnRole, [String])] = [
        (.date, ["date", "day", "tarih", "tarihi", "gün", "seans", "session"]),
        (.exercise, ["exercise", "exercises", "movement", "lift", "hareket", "egzersiz"]),
        (.weight, ["weight", "load", "kg", "lb", "lbs", "ağırlık", "yük"]),
        (.reps, ["reps", "rep", "repetitions", "tekrar", "tekrarlar"]),
        (.setNumber, ["set", "sets", "set no", "set #", "#"]),
        (.workout, ["workout", "routine", "program", "template", "antrenman", "rutin"]),
        (.note, ["note", "notes", "comment", "comments", "not", "notlar", "açıklama"]),
    ]

    /// Words of a header: "1. Set (Ağırlık x Tekrar)" → ["1", "set", "agırlık", "x", "tekrar"].
    static func words(_ text: String) -> [String] {
        text.matchingKey.split { !$0.isLetter && !$0.isNumber && $0 != "#" }.map(String.init)
    }

    /// The role a column name suggests, or nil:
    /// - a number with "set" ("1. Set", "Set 2", "S3"), or weight and reps together ("Ağırlık x Tekrar"): set cells;
    /// - otherwise the whole name, then any word, as a synonym, in the order of `synonyms`, so "Antrenman Tarihi" is
    ///   a date and "Weight 1" one side of a weight/reps pair.
    static func role(of header: String) -> ColumnRole? {
        let words = words(header)
        guard !words.isEmpty else { return nil }
        let hasNumber = words.contains { Int($0) != nil }
        let setNumberWord = words.contains { $0.wholeMatch(of: #/s\d+/#) != nil }
        let named = { (role: ColumnRole) in words.contains { word in names(of: role).contains(word) } }
        if (hasNumber && words.contains("set")) || setNumberWord || (named(.weight) && named(.reps)) {
            return .setCell
        }
        let key = words.joined(separator: " ")
        if let (role, _) = synonyms.first(where: { $0.1.contains { $0.matchingKey == key } }) {
            return role
        }
        return synonyms.first { role, _ in named(role) }?.0
    }

    private static func names(of role: ColumnRole) -> [String] {
        synonyms.first { $0.0 == role }?.1.map(\.matchingKey) ?? []
    }

    /// "Weight (lbs)", "lb": the header names pounds.
    static func namesPounds(_ header: String) -> Bool {
        words(header).contains { $0 == "lb" || $0 == "lbs" }
    }
}
