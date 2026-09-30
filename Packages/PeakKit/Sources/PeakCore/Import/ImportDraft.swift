import Foundation

public enum ImportFileError: Error, Equatable, Sendable {
    /// Valid JSON, but not Peak data (no `sessions`).
    case notPeakJSON
    /// Peak JSON that is damaged or has a wrong value: what and where ("sessions[0].date: expected a date").
    case invalidJSON(String)
    /// An .xlsx file whose ZIP or XML is broken.
    case damagedWorkbook
    /// A workbook far larger than a training log (`XLSXReader.maxUnpackedBytes`).
    case tooLarge
    /// Binary data that is not a spreadsheet, such as a photo.
    case notASpreadsheet
    /// An old Excel 97–2003 workbook (.xls): to be saved as .xlsx first.
    case legacyExcel
    /// A workbook without visible sheets, or a sheet file without rows.
    case empty
    /// Text in an encoding Peak cannot read.
    case unreadable
}

/// A file being imported, before it is confirmed: what the import screen (S-10) shows and changes
/// (docs/IMPORT_FORMAT.md).
///
/// Peak JSON is ready as it is. A spreadsheet keeps its sheets and a mapping, which starts as `SheetAnalyzer`'s guess
/// and follows the user's changes; `converted()` turns the chosen sheet into Peak JSON for `PeakImporter`.
public struct ImportDraft: Sendable {
    public enum Content: Sendable {
        case json(PeakExportV1)
        case sheets([RawTable])
    }

    public let fileName: String
    public private(set) var content: Content
    /// How a CSV or TSV file was read; `nil` for other files.
    public private(set) var csvFormat: CSVFormat?
    public private(set) var sheetIndex = 0
    /// How the chosen sheet is read; `nil` for Peak JSON.
    public var mapping: SheetMapping?
    private let bytes: Data

    /// Reads a picked file. The type comes from the extension, else from the content ("PK" starts a ZIP, "{" JSON).
    public static func load(_ data: Data, fileName: String) throws -> ImportDraft {
        let kind = kind(of: data, fileName: fileName)
        var draft: ImportDraft
        switch kind {
        case .json:
            draft = ImportDraft(fileName: fileName, content: .json(try decodeJSON(data)), bytes: data)
        case .xlsx:
            do {
                draft = ImportDraft(fileName: fileName, content: .sheets(try XLSXReader.read(data)), bytes: data)
            } catch XLSXReadError.tooLarge {
                throw ImportFileError.tooLarge
            } catch {
                throw ImportFileError.damagedWorkbook
            }
        case .csv(let delimiter):
            draft = try loadText(data, fileName: fileName, delimiter: delimiter)
        }
        if case .sheets(let sheets) = draft.content {
            guard let first = sheets.firstIndex(where: { !$0.rows.isEmpty }) else { throw ImportFileError.empty }
            draft.selectSheet(first)
        }
        return draft
    }

    /// A CSV or TSV file, after checking it is text at all.
    private static func loadText(_ data: Data, fileName: String, delimiter: Character?) throws -> ImportDraft {
        guard !data.isEmpty else { throw ImportFileError.empty }
        guard !data.starts(with: legacyExcelSignature) else { throw ImportFileError.legacyExcel }
        guard !isBinary(data) else { throw ImportFileError.notASpreadsheet }
        guard let (table, format) = try? CSVReader.read(data, name: fileName, delimiter: delimiter) else {
            throw ImportFileError.unreadable
        }
        var draft = ImportDraft(fileName: fileName, content: .sheets([table]), bytes: data)
        draft.csvFormat = format
        return draft
    }

    private init(fileName: String, content: Content, bytes: Data) {
        self.fileName = fileName
        self.content = content
        self.bytes = bytes
    }

    // MARK: Sheets

    public var sheets: [RawTable] {
        if case .sheets(let sheets) = content { sheets } else { [] }
    }

    /// The chosen sheet; `nil` for Peak JSON.
    public var table: RawTable? {
        sheets.indices.contains(sheetIndex) ? sheets[sheetIndex] : nil
    }

    /// Chooses a sheet and starts over with the analyzer's mapping for it.
    public mutating func selectSheet(_ index: Int) {
        guard sheets.indices.contains(index) else { return }
        sheetIndex = index
        mapping = SheetAnalyzer.analyze(sheets[index])
    }

    /// Names the row holding the column names (`nil`: none) and takes the roles those names suggest.
    public mutating func setHeaderRow(_ row: Int?) {
        guard let table, var mapping else { return }
        mapping.headerRow = row
        mapping.roles =
            row.map { SheetAnalyzer.roles(headerRow: $0, in: table) } ?? SheetAnalyzer.roles(withoutHeaderIn: table)
        self.mapping = mapping
    }

    /// Reads a CSV file again with another delimiter; the mapping starts over.
    public mutating func setDelimiter(_ delimiter: Character) {
        guard csvFormat != nil, let (table, format) = try? CSVReader.read(bytes, name: fileName, delimiter: delimiter)
        else { return }
        content = .sheets([table])
        csvFormat = format
        selectSheet(0)
    }

    /// Reads a CSV file's numbers with another decimal separator ("27,5" or "27.5").
    public mutating func setDecimalSeparator(_ separator: Character) {
        guard var format = csvFormat, var table else { return }
        format.decimalSeparator = separator
        table.decimalSeparator = separator
        csvFormat = format
        content = .sheets([table])
    }

    // MARK: Result

    /// The file as Peak JSON, with the cells that could not be read.
    public func converted() -> SheetConverter.Result {
        switch content {
        case .json(let file): (file, [])
        case .sheets:
            if let table, let mapping {
                SheetConverter.convert(table, mapping: mapping)
            } else {
                (PeakExportV1(sessions: []), [])
            }
        }
    }

    // MARK: Checks

    /// Peak JSON, or why not: not JSON at all or cut short ("line 3, column 12"), JSON of something else, or a value
    /// of the wrong kind ("sessions[0].date: expected a date as yyyy-MM-dd").
    static func decodeJSON(_ data: Data) throws -> PeakExportV1 {
        do {
            return try PeakJSON.decode(data)
        } catch let error as DecodingError {
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let object, object["sessions"] == nil {
                throw ImportFileError.notPeakJSON
            }
            throw ImportFileError.invalidJSON(describe(error, isJSON: object != nil))
        }
    }

    private static func describe(_ error: DecodingError, isJSON: Bool) -> String {
        let (path, detail): ([CodingKey], String) =
            switch error {
            case .typeMismatch(let type, let context): (context.codingPath, "expected \(kind(of: type))")
            case .valueNotFound(let type, let context): (context.codingPath, "missing \(kind(of: type))")
            case .keyNotFound(let key, let context): (context.codingPath + [key], "missing")
            case .dataCorrupted(let context): (context.codingPath, context.debugDescription)
            @unknown default: ([], "unreadable")
            }
        // Not parseable: the underlying error names the place ("around line 3, column 12").
        if !isJSON, case .dataCorrupted(let context) = error,
            let underlying = (context.underlyingError as NSError?)?.userInfo[NSDebugDescriptionErrorKey] as? String
        {
            return underlying
        }
        let place = path.reduce(into: "") { text, key in
            if let index = key.intValue {
                text += "[\(index)]"
            } else {
                text += text.isEmpty ? key.stringValue : ".\(key.stringValue)"
            }
        }
        return place.isEmpty ? detail : "\(place): \(detail)"
    }

    private static func kind(of type: Any.Type) -> String {
        switch type {
        case is String.Type: "text"
        case is Int.Type: "a whole number"
        case is Double.Type: "a number"
        case is Bool.Type: "true or false"
        case is [Any].Type: "a list"
        default: "a value"
        }
    }

    /// The start of an OLE compound file: Excel 97–2003 (.xls) and other old Office files.
    static let legacyExcelSignature: [UInt8] = [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1]

    /// NUL bytes, or many control characters, in what should be text (without a UTF-16 byte order mark).
    static func isBinary(_ data: Data) -> Bool {
        let head = data.prefix(4_096)
        if head.starts(with: [0xFF, 0xFE]) || head.starts(with: [0xFE, 0xFF]) { return false }
        if head.contains(0) { return true }
        let controls = head.filter { $0 < 0x20 && $0 != 0x09 && $0 != 0x0A && $0 != 0x0D }.count
        return controls * 10 > head.count
    }

    // MARK: File type

    enum Kind: Equatable {
        case json, xlsx
        case csv(delimiter: Character?)
    }

    static func kind(of data: Data, fileName: String) -> Kind {
        switch URL(filePath: fileName).pathExtension.lowercased() {
        case "json": return .json
        // A CSV saved under an .xlsx name is read as the text it is.
        case "xlsx" where data.starts(with: [0x50, 0x4B]): return .xlsx
        case "tsv", "tab": return .csv(delimiter: "\t")
        case "csv", "txt": return .csv(delimiter: nil)
        default: break
        }
        if data.starts(with: [0x50, 0x4B]) { return .xlsx }
        let start = data.prefix(64).drop { [0x20, 0x09, 0x0A, 0x0D, 0xEF, 0xBB, 0xBF].contains($0) }
        return start.first == UInt8(ascii: "{") ? .json : .csv(delimiter: nil)
    }
}
