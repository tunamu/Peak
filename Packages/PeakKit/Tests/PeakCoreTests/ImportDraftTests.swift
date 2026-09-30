import Foundation
import PeakCore
import Testing

/// F7-06: the file behind the import screen — loading any supported file, and the changes the mapping screen makes.
@Suite struct ImportDraftTests {
    func load(_ name: String, as fileName: String? = nil) throws -> ImportDraft {
        try ImportDraft.load(RawTableReaderTests.fixture(name), fileName: fileName ?? name)
    }

    @Test(arguments: [
        ("tr-excel.csv", SheetLayout.long), ("sets.tsv", .wide), ("block.xlsx", .block), ("workbook.xlsx", .long),
    ])
    func spreadsheetsOpenWithTheAnalyzersMapping(_ name: String, _ layout: SheetLayout) throws {
        let draft = try load(name)
        #expect(draft.mapping?.layout == layout)
        #expect(!draft.converted().data.sessions.isEmpty)
    }

    @Test func peakJSONNeedsNoMapping() throws {
        let draft = try ImportDraft.load(PeakJSONSchemaTests.example("full.json"), fileName: "backup.json")
        #expect(draft.mapping == nil && draft.table == nil)
        #expect(draft.converted().data.sessions.count == 4)
    }

    /// Files without a known extension are recognized by their content.
    @Test(arguments: [("workbook.xlsx", SheetLayout.long), ("tr-excel.csv", .long)])
    func typeFromContent(_ name: String, _ layout: SheetLayout) throws {
        #expect(try load(name, as: "download").mapping?.layout == layout)
        let json = try ImportDraft.load(PeakJSONSchemaTests.example("minimal.json"), fileName: "download")
        #expect(json.mapping == nil)
    }

    @Test func otherSheetsStartOverWithTheirOwnMapping() throws {
        var draft = try load("workbook.xlsx")
        #expect(draft.sheets.map(\.name) == ["Antrenman", "Notlar"])
        draft.selectSheet(1)
        #expect(draft.table?.name == "Notlar" && draft.mapping?.isConfident == false)
        draft.selectSheet(0)
        #expect(draft.mapping?.isConfident == true)
    }

    @Test func choosingTheHeaderRowRereadsTheRoles() throws {
        var draft = try load("no-header.csv")
        #expect(draft.mapping?.headerRow == nil)
        draft.setHeaderRow(0)
        // The first row is data, not names: only the set columns stay recognizable.
        #expect(draft.mapping?.roles == [.ignore, .ignore, .setCell, .setCell])
        draft.setHeaderRow(nil)
        #expect(draft.mapping?.roles == [.date, .ignore, .setCell, .setCell])
    }

    @Test func aDifferentDelimiterRereadsTheFile() throws {
        var draft = try load("tr-excel.csv")
        #expect(draft.csvFormat?.delimiter == ";" && draft.table?.columnCount == 6)
        draft.setDelimiter(",")
        #expect(draft.csvFormat?.delimiter == "," && draft.table?.columnCount != 6)
        draft.setDelimiter(";")
        #expect(draft.mapping?.layout == .long)
    }

    @Test func theDecimalSeparatorChangesHowWeightsRead() throws {
        var draft = try load("tr-excel.csv")
        let weight = { (draft: ImportDraft) in
            draft.converted().data.sessions.first?.exercises.first?.sets?.first?.weight
        }
        #expect(weight(draft) == 27.5)
        draft.setDecimalSeparator(".")
        // "27,5", "22,5" and "1.002,5" are no longer numbers: those rows are skipped with a warning each, and the
        // first set left is the curl's 15.
        #expect(weight(draft) == 15)
        #expect(draft.converted().issues.count == 3)
    }

    /// A CSV saved under an .xlsx name opens as the text it is.
    @Test func aCSVNamedXLSXOpensAsCSV() throws {
        let draft = try load("not-a-workbook.xlsx")
        #expect(draft.csvFormat?.delimiter == ";" && draft.table?.rows.first == ["Tarih", "Hareket"])
    }

    @Test func jsonThatIsNotPeakJSON() {
        #expect(throws: ImportFileError.notPeakJSON) {
            try ImportDraft.load(Data(#"{ "hello": 1 }"#.utf8), fileName: "x.json")
        }
    }

    @Test func emptyFiles() {
        #expect(throws: ImportFileError.empty) {
            try ImportDraft.load(Data("\n\n".utf8), fileName: "x.csv")
        }
    }
}
