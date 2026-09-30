import Foundation

/// A sheet of text cells, as read from a spreadsheet or CSV file, before its layout is known (docs/IMPORT_FORMAT.md
/// › Spreadsheets). Layout detection and mapping (F7-05) work on this, whatever the file type was.
///
/// Rows are rectangular (short rows are padded with empty cells), cells are trimmed, and empty rows and columns at the
/// end are dropped. Numbers keep their text: `decimalSeparator` says how to read them (`RawNumber`).
public struct RawTable: Equatable, Sendable {
    /// The sheet's name, or the file's name for CSV.
    public var name: String
    public var rows: [[String]]
    /// "," for a Turkish CSV ("27,5"); "." for XLSX, which stores numbers the same way in every language.
    public var decimalSeparator: Character

    public init(name: String, rows: [[String]], decimalSeparator: Character = ".") {
        self.name = name
        self.decimalSeparator = decimalSeparator
        self.rows = Self.tidy(rows)
    }

    public var columnCount: Int { rows.first?.count ?? 0 }

    /// The cell's number, read with this table's decimal separator.
    public func number(_ text: String) -> Double? {
        RawNumber.parse(text, decimalSeparator: decimalSeparator)
    }

    /// Trims cells, drops trailing empty rows and columns, pads rows to the same width.
    private static func tidy(_ rows: [[String]]) -> [[String]] {
        var rows = rows.map { $0.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } }
        while let last = rows.last, last.allSatisfy(\.isEmpty) {
            rows.removeLast()
        }
        let width = rows.map { row in (row.lastIndex { !$0.isEmpty } ?? -1) + 1 }.max() ?? 0
        return rows.map { row in
            Array(row.prefix(width)) + Array(repeating: "", count: max(0, width - row.count))
        }
    }
}

/// Numbers typed in either convention: "27,5" and "27.5", "1.234,5" and "1,234.5", with or without spaces.
public enum RawNumber {
    public static func parse(_ text: String, decimalSeparator: Character) -> Double? {
        var text = text.filter { !$0.isWhitespace && $0 != "\u{00A0}" && $0 != "\u{202F}" }
        guard !text.isEmpty else { return nil }
        let grouping: Character = decimalSeparator == "," ? "." : ","
        // Grouping marks only in their places: "1.234,5" yes, "27.5" with a comma decimal no.
        if text.contains(grouping) {
            let groups = text.split(separator: decimalSeparator, maxSplits: 1)[0]
            let pattern = grouping == "." ? #/^[-+]?\d{1,3}(\.\d{3})+$/# : #/^[-+]?\d{1,3}(,\d{3})+$/#
            guard groups.wholeMatch(of: pattern) != nil else { return nil }
            text.removeAll { $0 == grouping }
        }
        if decimalSeparator == "," {
            text = text.replacingOccurrences(of: ",", with: ".")
        }
        guard text.wholeMatch(of: #/[-+]?(\d+(\.\d*)?|\.\d+)([eE][-+]?\d+)?/#) != nil else { return nil }
        return Double(text)
    }
}
