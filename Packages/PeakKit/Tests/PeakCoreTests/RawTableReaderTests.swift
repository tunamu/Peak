import Foundation
import PeakCore
import Testing

/// F7-04: CSV, TSV and XLSX files into `RawTable`s. Fixtures: `Fixtures/Import/make_fixtures.py`.
@Suite struct RawTableReaderTests {
    static let fixtures = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "Fixtures/Import")

    static func fixture(_ name: String) throws -> Data {
        try Data(contentsOf: fixtures.appending(path: name))
    }

    // MARK: CSV

    /// The acceptance criterion: Turkish Excel's CSV (Windows-1254, `;`, CRLF, "27,5") reads right.
    @Test func turkishExcelCSV() throws {
        let (table, format) = try CSVReader.read(Self.fixture("tr-excel.csv"), name: "tr-excel.csv")
        #expect(format == CSVFormat(delimiter: ";", decimalSeparator: ",", encoding: CSVReader.windowsTurkish))
        #expect(
            table.rows == [
                ["Tarih", "Hareket", "Set", "Ağırlık", "Tekrar", "Not"],
                ["28.09.2026", "Dumbell Chest Press", "1", "27,5", "9", ""],
                ["28.09.2026", "Dumbell Chest Press", "2", "22,5", "13", "Son set; zorlandım"],
                ["28.09.2026", "İncline Dumbell Curl", "1", "15", "9", "İki\nsatır"],
                ["30.09.2026", "Lat Pulldown", "1", "1.002,5", "8", "Tırnak \"içinde\""],
            ])
        #expect(table.number("27,5") == 27.5)
        #expect(table.number("1.002,5") == 1_002.5)
        #expect(table.name == "tr-excel.csv")
    }

    @Test func utf8CSVWithBOMAndCommas() throws {
        let (table, format) = try CSVReader.read(Self.fixture("utf8-bom.csv"), name: "log.csv")
        #expect(format == CSVFormat(delimiter: ",", decimalSeparator: ".", encoding: .utf8))
        #expect(table.rows[0] == ["Date", "Exercise", "Weight", "Reps"])
        #expect(table.rows[1] == ["2026-09-28", "Row, seated", "60.5", "8"])
        #expect(table.number("60.5") == 60.5)
    }

    @Test(arguments: [nil, Character("\t")])
    func tsvWithSetCells(_ delimiter: Character?) throws {
        let (table, format) = try CSVReader.read(Self.fixture("sets.tsv"), name: "sets.tsv", delimiter: delimiter)
        #expect(format.delimiter == "\t" && format.decimalSeparator == ",")
        #expect(
            table.rows == [["Hareket", "1. Set", "2. Set"], ["Fly", "50x7", "45x8:9"], ["Row", "27,5 x 9", "-"]])
    }

    @Test func utf16WithBOM() throws {
        var data = Data([0xFF, 0xFE])
        data.append(try #require("Hareket;Ağırlık\nRow;27,5\n".data(using: .utf16LittleEndian)))
        let (table, format) = try CSVReader.read(data, name: "x.csv")
        #expect(format.encoding == .utf16 && format.delimiter == ";")
        #expect(table.rows == [["Hareket", "Ağırlık"], ["Row", "27,5"]])
    }

    @Test(arguments: [
        // A lone column: nothing to split on, read as one field per line.
        ("Row\nFly\n", [["Row"], ["Fly"]]),
        // Short rows are padded, trailing empty columns and rows dropped.
        ("a;b;c\n1;2\n;;\n\n", [["a", "b", "c"], ["1", "2", ""]]),
        // A quote in the middle of a field is text; one at the start opens a quoted field.
        ("a,b\n5\" tall,\"x\"\"y\"\n", [["a", "b"], ["5\" tall", "x\"y"]]),
        // Old Mac line ends.
        ("a;b\r1;2\r", [["a", "b"], ["1", "2"]]),
    ])
    func csvEdgeCases(_ text: String, _ rows: [[String]]) throws {
        #expect(try CSVReader.read(Data(text.utf8), name: "x").table.rows == rows)
    }

    @Test func datesAreNoEvidenceForADecimalPoint() throws {
        let text = "Tarih,Ağırlık\n28.09.2026,\"27,5\"\n29.09.2026,\"30,0\"\n"
        #expect(try CSVReader.read(Data(text.utf8), name: "x").format.decimalSeparator == ",")
    }

    @Test(arguments: [
        ("27,5", Character(","), 27.5), ("27.5", ".", 27.5), ("1.234,5", ",", 1_234.5), ("1,234.5", ".", 1_234.5),
        ("-3", ",", -3), (" 12 ", ".", 12), ("1 234,5", ",", 1_234.5), (",5", ",", 0.5),
    ])
    func numbers(_ text: String, _ decimal: Character, _ value: Double) {
        #expect(RawNumber.parse(text, decimalSeparator: decimal) == value)
    }

    @Test(arguments: [
        ("27.5", Character(",")), ("12.34.5", ","), ("27,5x8", ","), ("", "."), ("abc", "."), ("1,23", "."),
    ])
    func notNumbers(_ text: String, _ decimal: Character) {
        #expect(RawNumber.parse(text, decimalSeparator: decimal) == nil)
    }

    // MARK: XLSX

    @Test func workbookSheetsAndCells() throws {
        let sheets = try XLSXReader.read(Self.fixture("workbook.xlsx"))
        #expect(sheets.map(\.name) == ["Antrenman", "Notlar"])
        let sheet = sheets[0]
        #expect(sheet.decimalSeparator == ".")
        #expect(
            sheet.rows == [
                ["Tarih", "Hareket", "Ağırlık", "Tekrar", "Saat"],
                ["2026-09-28", "Dumbell Chest Press", "27.5", "9", "18:30"],
                ["2026-09-28", "Row", "", "13", ""],
                ["", "", "", "", ""],
                ["2026-09-30", "TRUE", "#N/A", "0.0015", "x"],
            ])
        #expect(sheets[1].rows == [["Notlar", "42"]])
    }

    @Test func the1904DateSystem() throws {
        let sheets = try XLSXReader.read(Self.fixture("date1904.xlsx"))
        #expect(sheets.first?.rows == [["2026-09-28", "60"]])
    }

    @Test(arguments: ["not-a-workbook.xlsx", "tr-excel.csv"])
    func otherFilesAreNotWorkbooks(_ name: String) throws {
        #expect(throws: XLSXReadError.notAWorkbook) {
            try XLSXReader.read(Self.fixture(name))
        }
    }
}
