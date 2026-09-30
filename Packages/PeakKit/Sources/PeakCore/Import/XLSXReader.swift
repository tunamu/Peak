import Foundation
import ZIPFoundation

public enum XLSXReadError: Error, Equatable {
    /// Not a ZIP file, or not an Excel workbook inside.
    case notAWorkbook
    /// A part of the workbook is missing or is not valid XML.
    case damaged(String)
    /// The unpacked workbook is larger than `XLSXReader.maxUnpackedBytes`.
    case tooLarge
}

/// Reads the visible sheets of an .xlsx workbook into `RawTable`s, in the workbook's order.
///
/// An .xlsx file is a ZIP of XML parts: `xl/workbook.xml` lists the sheets, `xl/sharedStrings.xml` holds the text,
/// `xl/styles.xml` says which cells are dates, and each sheet is `xl/worksheets/sheetN.xml`. Cells come out as text:
/// - Numbers as stored ("27.5"; Excel writes a point in every language), so the table's decimal separator is ".".
/// - Dates as "2026-09-28" (with " 18:30" when there is a time), from the date serial and the cell's number format,
///   in the 1900 or 1904 date system the workbook uses.
/// - Formulas as their last calculated value; booleans as "TRUE"/"FALSE".
public enum XLSXReader {
    /// A guard against ZIP bombs: training logs are far smaller.
    public static let maxUnpackedBytes: UInt64 = 64 * 1_024 * 1_024

    public static func read(_ data: Data) throws -> [RawTable] {
        guard let archive = try? Archive(data: data, accessMode: .read),
            archive["xl/workbook.xml"] != nil
        else { throw XLSXReadError.notAWorkbook }
        guard archive.reduce(0, { $0 + $1.uncompressedSize }) <= maxUnpackedBytes else {
            throw XLSXReadError.tooLarge
        }
        let workbook = try part("xl/workbook.xml", in: archive)
        let relations = try part("xl/_rels/workbook.xml.rels", in: archive)
        let strings = try optionalPart("xl/sharedStrings.xml", in: archive).map(sharedStrings) ?? []
        let dateStyles = try optionalPart("xl/styles.xml", in: archive).map(dateFormats) ?? [:]
        let uses1904 = workbook.child("workbookPr")?.attributes["date1904"].map { $0 == "1" || $0 == "true" } ?? false
        let cells = CellReader(strings: strings, dateStyles: dateStyles, uses1904: uses1904)

        var targets: [String: String] = [:]
        for relation in relations.children("Relationship") {
            if let id = relation.attributes["Id"], let target = relation.attributes["Target"] {
                targets[id] = target.hasPrefix("/") ? String(target.dropFirst()) : "xl/\(target)"
            }
        }
        return try (workbook.child("sheets")?.children("sheet") ?? []).compactMap { sheet in
            // Hidden sheets are left out: nobody sees them in Excel, and they tend to hold lookup lists.
            guard sheet.attributes["state"] == nil || sheet.attributes["state"] == "visible",
                let id = sheet.attributes["id"], let path = targets[id]
            else { return nil }
            let rows = try cells.rows(of: part(path, in: archive))
            return RawTable(name: sheet.attributes["name"] ?? "", rows: rows)
        }
    }

    // MARK: Parts

    private static func optionalPart(_ path: String, in archive: Archive) throws -> XMLTree? {
        archive[path] == nil ? nil : try part(path, in: archive)
    }

    private static func part(_ path: String, in archive: Archive) throws -> XMLTree {
        guard let entry = archive[path] else { throw XLSXReadError.damaged(path) }
        var data = Data()
        do {
            _ = try archive.extract(entry) { data.append($0) }
        } catch {
            throw XLSXReadError.damaged(path)
        }
        guard let root = XMLTree.parse(data) else { throw XLSXReadError.damaged(path) }
        return root
    }

    /// The shared strings in order. Rich text is joined; phonetic hints (`rPh`) are left out.
    private static func sharedStrings(_ root: XMLTree) -> [String] {
        root.children("si").map { $0.allText(skipping: ["rPh"]) }
    }

    /// For each cell style index (`s`) that shows a date or time: whether it has a date part and a time part.
    private static func dateFormats(_ root: XMLTree) -> [Int: DateFormatKind] {
        var custom: [Int: String] = [:]
        for format in root.child("numFmts")?.children("numFmt") ?? [] {
            if let id = format.attributes["numFmtId"].flatMap(Int.init), let code = format.attributes["formatCode"] {
                custom[id] = code
            }
        }
        var kinds: [Int: DateFormatKind] = [:]
        for (index, style) in (root.child("cellXfs")?.children("xf") ?? []).enumerated() {
            guard let id = style.attributes["numFmtId"].flatMap(Int.init) else { continue }
            if let kind = DateFormatKind(builtIn: id) ?? custom[id].flatMap(DateFormatKind.init(code:)) {
                kinds[index] = kind
            }
        }
        return kinds
    }
}

/// What a number format shows of a date serial.
struct DateFormatKind: Equatable {
    var hasDate: Bool
    var hasTime: Bool

    /// Excel's built-in formats: 14–17 and 22 are dates, 18–21 and 45–47 times.
    init?(builtIn id: Int) {
        switch id {
        case 14...17: self.init(hasDate: true, hasTime: false)
        case 22: self.init(hasDate: true, hasTime: true)
        case 18...21, 45...47: self.init(hasDate: false, hasTime: true)
        default: return nil
        }
    }

    /// A custom format such as "dd.mm.yyyy" or "[$-41F]d mmmm yyyy;@". Quoted text, escapes and brackets are
    /// ignored; "m" alone could be months or minutes, so it decides nothing.
    init?(code: String) {
        var plain = code.replacing(#/"[^"]*"/#, with: "").replacing(#/\\./#, with: "").replacing(
            #/\[[^\]]*\]/#, with: "")
        plain = plain.lowercased()
        let hasDate = plain.contains("y") || plain.contains("d")
        let hasTime = plain.contains("h") || plain.contains("s")
        guard hasDate || hasTime else { return nil }
        self.init(hasDate: hasDate, hasTime: hasTime)
    }

    init(hasDate: Bool, hasTime: Bool) {
        self.hasDate = hasDate
        self.hasTime = hasTime
    }
}

/// Turns sheet XML into rows of text.
private struct CellReader {
    let strings: [String]
    let dateStyles: [Int: DateFormatKind]
    let uses1904: Bool

    func rows(of sheet: XMLTree) -> [[String]] {
        var rows: [[String]] = []
        for row in sheet.child("sheetData")?.children("row") ?? [] {
            let rowIndex = row.attributes["r"].flatMap(Int.init).map { $0 - 1 } ?? rows.count
            guard rowIndex >= rows.count, rowIndex - rows.count < 1_000_000 else { continue }
            rows += Array(repeating: [], count: rowIndex - rows.count)
            var cells: [String] = []
            for cell in row.children("c") {
                let column = cell.attributes["r"].flatMap(Self.column) ?? cells.count
                guard column >= cells.count, column < 16_384 else { continue }
                cells += Array(repeating: "", count: column - cells.count)
                cells.append(text(of: cell))
            }
            rows.append(cells)
        }
        return rows
    }

    private func text(of cell: XMLTree) -> String {
        let value = cell.child("v")?.text ?? ""
        switch cell.attributes["t"] {
        case "s": return Int(value).flatMap { strings.indices.contains($0) ? strings[$0] : nil } ?? ""
        case "inlineStr": return cell.child("is")?.allText(skipping: ["rPh"]) ?? ""
        case "b": return value == "1" ? "TRUE" : "FALSE"
        case "str", "e": return value
        default: break
        }
        if let style = cell.attributes["s"].flatMap(Int.init), let kind = dateStyles[style],
            let serial = Double(value)
        {
            return Self.format(serial: serial, kind: kind, uses1904: uses1904)
        }
        // Excel writes plain decimals; only rewrite exponents ("1.5E-3").
        if value.contains(where: { $0 == "E" || $0 == "e" }), let number = Double(value) {
            return number == number.rounded() && abs(number) < 1e15 ? String(Int(number)) : String(number)
        }
        return value
    }

    /// "B12" → 1 (zero-based column).
    private static func column(_ reference: String) -> Int? {
        let letters = reference.prefix { $0.isLetter }.uppercased()
        guard !letters.isEmpty, letters.count <= 3 else { return nil }
        return letters.unicodeScalars.reduce(0) { $0 * 26 + Int($1.value) - 64 } - 1
    }

    /// A date serial as "2026-09-28", "2026-09-28 18:30" or "18:30". Day 0 is 1899-12-30 (1900 system, which
    /// counts a 29 February 1900 that never was) or 1904-01-01.
    static func format(serial: Double, kind: DateFormatKind, uses1904: Bool) -> String {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let epoch =
            uses1904 ? DateComponents(year: 1904, month: 1, day: 1) : DateComponents(year: 1899, month: 12, day: 30)
        guard let start = utc.date(from: epoch) else { return String(serial) }
        // Whole seconds, so 0.7708333 is 18:30:00 and not 18:29:59.
        let date = start.addingTimeInterval((serial * 86_400).rounded())
        let parts = utc.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let day = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        let seconds = parts.second ?? 0
        let time =
            seconds == 0
            ? String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
            : String(format: "%02d:%02d:%02d", parts.hour ?? 0, parts.minute ?? 0, seconds)
        // What the format shows, as Excel shows it: "dd.mm.yyyy" drops the time even when the serial has one.
        switch (kind.hasDate, kind.hasTime) {
        case (true, true): return "\(day) \(time)"
        case (true, false): return day
        default: return time
        }
    }
}
