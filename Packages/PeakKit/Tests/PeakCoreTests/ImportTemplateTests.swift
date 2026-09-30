import Foundation
import PeakCore
import Testing

/// F7-07: the import templates read back as the long layout they are, and the files in docs/import-templates are
/// the generator's bytes. After changing `ImportTemplate`, rewrite them with
/// `PEAK_WRITE_TEMPLATES=1 swift test --filter ImportTemplateTests`.
@Suite struct ImportTemplateTests {
    static let folder = PeakJSONSchemaTests.schemaFolder.deletingLastPathComponent().appending(path: "import-templates")

    typealias Template = (ImportTemplate.Format, ImportTemplate.Language)

    static let all: [Template] = ImportTemplate.Format.allCases.flatMap(templates)

    static func templates(in format: ImportTemplate.Format) -> [Template] {
        ImportTemplate.Language.allCases.map { (format, $0) }
    }

    /// The acceptance criterion: a filled template imports without a question or a problem.
    @MainActor
    @Test(arguments: all)
    func aFilledTemplateImports(_ format: ImportTemplate.Format, _ language: ImportTemplate.Language) throws {
        let name = ImportTemplate.fileName(format, language: language)
        let draft = try ImportDraft.load(ImportTemplate.data(format, language: language), fileName: name)
        if format == .json {
            // Peak JSON needs no mapping, and matches the schema.
            #expect(draft.mapping == nil)
            let validator = try JSONSchemaValidator(
                schema: Data(
                    contentsOf: PeakJSONSchemaTests.schemaFolder.appending(path: "peak-workout-data.v1.schema.json")))
            #expect(try validator.errors(in: ImportTemplate.data(format, language: language)) == [])
        } else {
            let mapping = try #require(draft.mapping)
            #expect(mapping.layout == .long && mapping.isConfident && mapping.weightUnit == .kg)
            #expect(mapping.roles == [.date, .workout, .exercise, .setNumber, .weight, .reps, .note])
        }

        let (data, issues) = draft.converted()
        #expect(issues.isEmpty)
        #expect(data.sessions.map(\.date?.description) == ["2026-09-28", "2026-09-30"])
        #expect(data.sessions.map(\.title) == ["Chest & Biceps", "Back & Triceps"])
        let first = data.sessions[0].exercises
        #expect(first.map(\.exerciseName) == ["Dumbbell Chest Press", "Incline Dumbbell Curl"])
        #expect(first[0].sets?.map(\.weight) == [27.5, 22.5] && first[0].sets?.map(\.reps) == [9, 13])

        let preview = try PeakImporter(context: makeContext()).preview(data)
        #expect(preview.canImport && preview.newSessions == 2 && preview.newSets == 5 && preview.issues.isEmpty)
    }

    @Test(arguments: all)
    func theSameTemplateIsTheSameBytes(_ format: ImportTemplate.Format, _ language: ImportTemplate.Language) throws {
        #expect(try ImportTemplate.data(format, language: language) == ImportTemplate.data(format, language: language))
    }

    @Test(arguments: all)
    func repositoryFilesMatchTheGenerator(_ format: ImportTemplate.Format, _ language: ImportTemplate.Language) throws {
        let url = Self.folder.appending(path: ImportTemplate.fileName(format, language: language))
        let generated = try ImportTemplate.data(format, language: language)
        if ProcessInfo.processInfo.environment["PEAK_WRITE_TEMPLATES"] == "1" {
            try generated.write(to: url)
        }
        #expect(try Data(contentsOf: url) == generated, "\(url.lastPathComponent) is out of date")
    }

    @Test func theTurkishCSVFollowsTurkishExcel() throws {
        let data = try ImportTemplate.data(.csv, language: .turkish)
        #expect(data.starts(with: [0xEF, 0xBB, 0xBF]))
        let (table, format) = try CSVReader.read(data, name: "x.csv")
        #expect(format.delimiter == ";" && format.decimalSeparator == ",")
        #expect(table.rows[1].prefix(5) == ["28.09.2026", "Chest & Biceps", "Dumbbell Chest Press", "1", "27,5"])
    }

    @Test func languageFollowsTheDevice() {
        #expect(ImportTemplate.Language(locale: Locale(identifier: "tr_TR")) == .turkish)
        #expect(ImportTemplate.Language(locale: Locale(identifier: "en_GB")) == .english)
        #expect(ImportTemplate.Language(locale: Locale(identifier: "de_DE")) == .english)
    }
}
