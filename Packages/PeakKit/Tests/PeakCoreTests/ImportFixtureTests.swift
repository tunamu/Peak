import Foundation
import PeakCore
import SwiftData
import Testing
import ZIPFoundation

/// F7-08: the real `/coach` history, a large synthetic log, and broken files. Fixtures: `Fixtures/Import/`,
/// written by `make_fixtures.py`.
@Suite struct ImportFixtureTests {
    static func load(_ name: String) throws -> ImportDraft {
        try ImportDraft.load(RawTableReaderTests.fixture(name), fileName: URL(filePath: name).lastPathComponent)
    }

    // MARK: Broken files

    /// The acceptance criterion: every broken file ends in its own error, which the app words for people
    /// (ImportDataRow), and never in a crash or a sheet of noise.
    @Test(arguments: [
        ("broken/truncated.xlsx", ImportFileError.damagedWorkbook),
        ("broken/missing-sheet.xlsx", .damagedWorkbook),
        ("broken/bad-xml.xlsx", .damagedWorkbook),
        ("broken/only-hidden.xlsx", .empty),
        ("broken/other-app.json", .notPeakJSON),
        ("broken/photo.csv", .notASpreadsheet),
        ("broken/empty.csv", .empty),
    ])
    func brokenFilesSayWhatIsWrong(_ name: String, _ error: ImportFileError) {
        #expect(throws: error) { try Self.load(name) }
    }

    @Test func oldExcelFilesAskForXLSX() {
        let xls = Data([0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1]) + Data(count: 512)
        #expect(throws: ImportFileError.legacyExcel) { try ImportDraft.load(xls, fileName: "log.xls") }
    }

    /// Damaged JSON says where: the end of a file cut short, or the field with the wrong value.
    @Test(arguments: [
        ("broken/cut-short.json", "end of file"),
        ("broken/wrong-date.json", "sessions[0].date"),
    ])
    func damagedJSONSaysWhere(_ name: String, _ place: String) throws {
        do {
            _ = try Self.load(name)
            Issue.record("\(name) loaded")
        } catch ImportFileError.invalidJSON(let detail) {
            #expect(detail.localizedCaseInsensitiveContains(place), "\(detail)")
        }
    }

    /// A ZIP bomb: 65 MB of zeros in a few kilobytes is refused before it is unpacked.
    @Test func hugeWorkbooksAreRefused() throws {
        let archive = try Archive(accessMode: .create)
        let size = Int(XLSXReader.maxUnpackedBytes) + 1_024 * 1_024
        try archive.addEntry(
            with: "xl/workbook.xml", type: .file, uncompressedSize: Int64(size), compressionMethod: .deflate
        ) { _, chunk in Data(count: chunk) }
        let data = try #require(archive.data)
        #expect(data.count < 1_024 * 1_024)
        #expect(throws: ImportFileError.tooLarge) { try ImportDraft.load(data, fileName: "bomb.xlsx") }
    }

    // MARK: Real and large files

    /// Tuna's real history: the block layout, one session per day across sections, undated rows dated by the importer.
    @MainActor
    @Test func theRealCoachHistory() throws {
        let draft = try Self.load("antrenman-gecmisi.xlsx")
        #expect(draft.mapping?.layout == .block && draft.mapping?.isConfident == true)
        let (data, issues) = draft.converted()
        #expect(issues.isEmpty)
        #expect(data.sessions.count == 22)
        #expect(data.sessions.reduce(0) { $0 + $1.exercises.reduce(0) { $0 + ($1.sets ?? []).count } } == 165)
        let dated = data.sessions.compactMap { session in session.date.map { ($0, session) } }
            .sorted { $0.0 < $1.0 }.map(\.1)
        #expect(
            dated.map(\.title) == [
                "Göğüs (Chest) & Triceps (Arka Kol)", "Sırt (Back) & Biceps (Pazu)",
                "Omuz (Shoulders) & Triceps (Arka Kol)",
                "Göğüs (Chest) & Biceps (Pazu)", "Sırt (Back) & Triceps (Arka Kol)", "Omuz (Shoulders) & Biceps (Pazu)",
                "Göğüs (Chest) & Triceps (Arka Kol)", "Sırt (Back) & Biceps (Pazu)",
                "Omuz (Shoulders) & Triceps (Arka Kol)",
                "Göğüs (Chest) & Biceps (Pazu)",
            ])
        #expect(dated.allSatisfy { $0.exercises.count == 5 })

        let context = try makeContext()
        let importer = PeakImporter(context: context)
        let preview = try importer.preview(data)
        #expect(preview.canImport && preview.newSessions == 22 && preview.warnings.count == 12)
        try importer.commit(data)
        #expect(try importer.preview(data).duplicateSessions == 22)
        #expect(try ExerciseRepository(context: context).all().count == 16)
    }

    /// Twelve weeks of sets: read, converted and previewed quickly.
    @MainActor
    @Test func aLargeLog() throws {
        let clock = ContinuousClock()
        var preview = ImportPreview()
        let elapsed = try clock.measure {
            let draft = try Self.load("synthetic-long.xlsx")
            #expect(draft.mapping?.layout == .long && draft.mapping?.isConfident == true)
            preview = try PeakImporter(context: makeContext()).preview(draft.converted().data)
        }
        #expect(preview.newSessions == 36 && preview.newSets == 432 && preview.canImport)
        #expect(elapsed < .seconds(3), "\(elapsed)")
    }
}
