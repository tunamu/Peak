import Foundation

/// How a CSV file was read: shown on the mapping screen and changeable there when the guess is wrong.
public struct CSVFormat: Equatable, Sendable {
    public var delimiter: Character
    public var decimalSeparator: Character
    public var encoding: String.Encoding

    public init(delimiter: Character, decimalSeparator: Character, encoding: String.Encoding) {
        self.delimiter = delimiter
        self.decimalSeparator = decimalSeparator
        self.encoding = encoding
    }
}

public enum CSVReadError: Error, Equatable {
    case unreadableText
}

/// Reads CSV and TSV files (RFC 4180: quoted fields may hold delimiters, quotes as `""` and line breaks) and works out
/// what the file does not say:
/// - **Encoding:** UTF-8 (with or without BOM), UTF-16 with a BOM, else Windows-1254, which Turkish Excel uses for
///   "CSV (Comma delimited)".
/// - **Delimiter:** `,` `;` tab or `|`, whichever splits the first lines into the same number of fields most
///   consistently. Turkish Excel writes `;`.
/// - **Decimal separator:** from the numbers in the file ("27,5" against "27.5"); `,` when the file gives no sign
///   and uses `;`.
public enum CSVReader {
    public static let delimiters: [Character] = [",", ";", "\t", "|"]

    /// - Parameter delimiter: A known delimiter (tab for .tsv); `nil` detects it.
    public static func read(
        _ data: Data, name: String, delimiter: Character? = nil
    ) throws -> (table: RawTable, format: CSVFormat) {
        let (text, encoding) = try decode(data)
        let delimiter = delimiter ?? detectDelimiter(in: text)
        let rows = parse(text, delimiter: delimiter)
        let decimal = detectDecimalSeparator(in: rows, delimiter: delimiter)
        let format = CSVFormat(delimiter: delimiter, decimalSeparator: decimal, encoding: encoding)
        return (RawTable(name: name, rows: rows, decimalSeparator: decimal), format)
    }

    // MARK: Encoding

    /// Windows-1254 (Turkish), the "ANSI" code page of Turkish Windows.
    public static let windowsTurkish = String.Encoding(
        rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.windowsLatin5.rawValue)))

    static func decode(_ data: Data) throws -> (String, String.Encoding) {
        let bytes = [UInt8](data.prefix(3))
        if bytes.starts(with: [0xEF, 0xBB, 0xBF]), let text = String(data: data.dropFirst(3), encoding: .utf8) {
            return (text, .utf8)
        }
        if bytes.starts(with: [0xFF, 0xFE]) || bytes.starts(with: [0xFE, 0xFF]),
            let text = String(data: data, encoding: .utf16)
        {
            return (text, .utf16)
        }
        if let text = String(data: data, encoding: .utf8) {
            return (text, .utf8)
        }
        if let text = String(data: data, encoding: windowsTurkish) {
            return (text, windowsTurkish)
        }
        throw CSVReadError.unreadableText
    }

    // MARK: Parsing

    /// Splits text into rows of fields. Line ends may be CRLF, LF or CR.
    static func parse(_ text: String, delimiter: Character, limit: Int = .max) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var isQuoted = false
        var iterator = text.makeIterator()
        var pending = iterator.next()

        func endRow() {
            row.append(field)
            field = ""
            // A blank line is not a row of one empty field.
            if !(row.count == 1 && row[0].isEmpty) {
                rows.append(row)
            }
            row = []
        }

        while let character = pending, rows.count < limit {
            pending = iterator.next()
            if isQuoted {
                if character == "\"" {
                    if pending == "\"" {
                        field.append("\"")
                        pending = iterator.next()
                    } else {
                        isQuoted = false
                    }
                } else {
                    field.append(character)
                }
                continue
            }
            switch character {
            case "\"" where field.isEmpty:
                isQuoted = true
            case delimiter:
                row.append(field)
                field = ""
            // Swift reads "\r\n" as one Character.
            case "\r\n", "\n", "\r":
                endRow()
            default:
                field.append(character)
            }
        }
        if !field.isEmpty || !row.isEmpty {
            endRow()
        }
        return rows
    }

    // MARK: Detection

    /// The delimiter whose field count is the same on the most of the first 20 lines, preferring more fields.
    static func detectDelimiter(in text: String) -> Character {
        var best: (delimiter: Character, score: (Int, Int)) = (",", (0, 0))
        for delimiter in delimiters {
            let counts = parse(text, delimiter: delimiter, limit: 20).map(\.count)
            let frequency = Dictionary(counts.map { ($0, 1) }, uniquingKeysWith: +)
            guard
                let (fields, lines) = frequency.filter({ $0.key > 1 }).max(by: {
                    ($0.value, $0.key) < ($1.value, $1.key)
                })
            else { continue }
            if (lines, fields) > best.score {
                best = (delimiter, (lines, fields))
            }
        }
        return best.delimiter
    }

    /// "," when more cells read as numbers with a decimal comma than with a point. Only whole cells count, and set
    /// cells like "27,5x8", so dates ("28.09.2026") are no evidence.
    static func detectDecimalSeparator(in rows: [[String]], delimiter: Character) -> Character {
        var comma = 0
        var point = 0
        for cell in rows.joined() {
            let cell = cell.trimmingCharacters(in: .whitespaces)
            guard let match = cell.wholeMatch(of: #/[-+]?\d+([.,])\d+(\s*(kg|lb|lbs)?\s*[x×*]\s*\d+(:\d+)?)?/#) else {
                continue
            }
            if match.output.1 == "," { comma += 1 } else { point += 1 }
        }
        if comma != point {
            return comma > point ? "," : "."
        }
        return delimiter == ";" ? "," : "."
    }
}
