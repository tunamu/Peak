import Foundation
import PeakCore
import SwiftData
import Testing

/// F7-05: layout detection, header names, set cells, and turning sheets into Peak JSON.
@Suite struct SheetLayoutTests {
    static func table(_ name: String, sheet: Int = 0) throws -> RawTable {
        let data = try RawTableReaderTests.fixture(name)
        if name.hasSuffix(".xlsx") {
            return try XLSXReader.read(data)[sheet]
        }
        return try CSVReader.read(data, name: name, delimiter: name.hasSuffix(".tsv") ? "\t" : nil).table
    }

    // MARK: Detection

    /// The acceptance criterion: every fixture is classified right.
    @Test(arguments: [
        ("tr-excel.csv", 0, SheetLayout.long, [ColumnRole.date, .exercise, .setNumber, .weight, .reps, .note], true),
        ("utf8-bom.csv", 0, .long, [.date, .exercise, .weight, .reps], true),
        ("us-long.csv", 0, .long, [.date, .exercise, .setNumber, .weight, .reps, .note], true),
        ("workbook.xlsx", 0, .long, [.date, .exercise, .weight, .reps, .ignore], true),
        ("sets.tsv", 0, .wide, [.exercise, .setCell, .setCell], true),
        ("wide-pairs.csv", 0, .wide, [.date, .workout, .exercise, .weight, .reps, .weight, .reps], true),
        ("block.csv", 0, .block, [.ignore, .ignore, .ignore, .ignore], true),
        ("block.xlsx", 0, .block, [.ignore, .ignore, .ignore, .ignore], true),
        ("ambiguous-dates.csv", 0, .long, [.date, .exercise, .weight, .reps], false),
        ("no-header.csv", 0, .long, [.date, .ignore, .setCell, .setCell], false),
        ("workbook.xlsx", 1, .long, [.ignore, .ignore], false),
    ])
    func fixturesAreClassified(
        _ name: String, _ sheet: Int, _ layout: SheetLayout, _ roles: [ColumnRole], _ isConfident: Bool
    ) throws {
        let mapping = SheetAnalyzer.analyze(try Self.table(name, sheet: sheet))
        #expect(mapping.layout == layout)
        #expect(mapping.roles == roles)
        #expect(mapping.isConfident == isConfident)
    }

    @Test func unitsAndDateOrders() throws {
        let american = SheetAnalyzer.analyze(try Self.table("us-long.csv"))
        #expect(american.weightUnit == .lb && american.dateOrder == .monthDayYear && american.headerRow == 0)
        let turkish = SheetAnalyzer.analyze(try Self.table("tr-excel.csv"))
        #expect(turkish.weightUnit == .kg && turkish.dateOrder == .dayMonthYear)
    }

    @Test(arguments: [
        ("Tarih", ColumnRole.date), ("Tarih / Seans", .date), ("Antrenman Tarihi", .date), ("Hareket", .exercise),
        ("Egzersiz Adı", .exercise), ("Ağırlık (kg)", .weight), ("Weight (lbs)", .weight), ("Weight 2", .weight),
        ("TEKRAR", .reps), ("Set", .setNumber), ("Set #", .setNumber), ("1. Set", .setCell), ("Set 3", .setCell),
        ("S2", .setCell), ("1. Set (Ağırlık x Tekrar)", .setCell), ("Set (Ağırlık x Tekrar)", .setCell),
        ("Antrenman", .workout), ("Notlar", .note),
    ])
    func headerNames(_ header: String, _ role: ColumnRole) {
        #expect(SheetAnalyzer.role(ofHeader: header) == role)
    }

    // MARK: Cells

    @Test(arguments: [
        ("27.5 x 9", SetCell(weight: 27.5, reps: 9)), ("27,5x9", SetCell(weight: 27.5, reps: 9)),
        ("27.5x8:9", SetCell(weight: 27.5, reps: 9, targetReps: 8)),
        ("60 kg × 8", SetCell(weight: 60, reps: 8, unit: .kg)),
        ("135LB*5", SetCell(weight: 135, reps: 5, unit: .lb)), (" 0 x 12 ", SetCell(weight: 0, reps: 12)),
    ])
    func setCells(_ text: String, _ set: SetCell) {
        #expect(SetCell.parse(text) == set)
    }

    @Test(arguments: ["-", "", "27.5", "x 9", "27.5 x", "27.5 x 9.5", "abc", "07.09.2026"])
    func notSetCells(_ text: String) {
        #expect(SetCell.parse(text) == nil)
    }

    @Test(arguments: [
        ("3. Seans (07.09.2026)", DateOrder.dayMonthYear, String?("2026-09-07"), Int?(3)),
        ("1. Seans", .dayMonthYear, nil, 1),
        ("Session 4", .dayMonthYear, nil, 4),
        ("2026-09-28", .monthDayYear, "2026-09-28", nil),
        ("2026-09-28 18:30", .dayMonthYear, "2026-09-28", nil),
        ("9/28/26", .monthDayYear, "2026-09-28", nil),
        ("28.09.2026", .dayMonthYear, "2026-09-28", nil),
    ])
    func sessionLabels(_ text: String, _ order: DateOrder, _ date: String?, _ number: Int?) {
        let label = SessionLabel.parse(text, order: order)
        #expect(label?.date?.description == date)
        #expect(label?.number == number)
    }

    @Test(arguments: ["Chest Press", "", "31.02.2026", "1. Set"])
    func notSessionLabels(_ text: String) {
        #expect(SessionLabel.parse(text, order: .dayMonthYear) == nil)
    }

    // MARK: Conversion

    func converted(_ name: String, sheet: Int = 0) throws -> (data: PeakExportV1, issues: [ImportIssue]) {
        let table = try Self.table(name, sheet: sheet)
        return SheetConverter.convert(table, mapping: SheetAnalyzer.analyze(table))
    }

    /// "Row: 60x8, 55x9" per exercise, sessions in order.
    func summary(_ data: PeakExportV1) -> [String] {
        data.sessions.map { session in
            let exercises = session.exercises.map { exercise in
                let sets = (exercise.sets ?? []).map { set in
                    let weight = set.weight.formatted(
                        .number.grouping(.never).locale(Locale(identifier: "en_US_POSIX")))
                    return "\(weight)x\(set.reps)" + (set.targetReps.map { ":\($0)" } ?? "")
                }
                return "\(exercise.exerciseName ?? "?"): \(sets.joined(separator: ", "))"
            }
            return "\(session.date?.description ?? "undated") | \(exercises.joined(separator: " | "))"
        }
    }

    @Test func turkishLongCSV() throws {
        let (data, issues) = try converted("tr-excel.csv")
        #expect(
            summary(data) == [
                "2026-09-28 | Dumbell Chest Press: 27.5x9, 22.5x13 | İncline Dumbell Curl: 15x9",
                "2026-09-30 | Lat Pulldown: 1002.5x8",
            ])
        #expect(data.sessions[0].note == "Son set; zorlandım; İki\nsatır")
        #expect(data.units?.weight == .kg && issues.isEmpty)
    }

    @Test(arguments: ["block.csv", "block.xlsx"])
    func blockHistory(_ name: String) throws {
        let (data, issues) = try converted(name)
        #expect(
            summary(data) == [
                "undated | Dumbell Chest Press: 22.5x9, 17.5x10 | İncline Smith Machine Press: 50x4, 40x6",
                "undated | Dumbell Chest Press: 25x7, 20x10",
                "2026-09-07 | Dumbell Chest Press: 25x9, 22.5x8 | V Bar Triceps Pushdown: 55x10, 50x12",
                "2026-09-28 | Dumbell Chest Press: 27.5x9, 22.5x13 | İncline Smith Machine Press: 55x6, 45x9",
                "undated | Lat Pulldown: 55x8, 55x8",
                "2026-09-09 | Lat Pulldown: 60x8, 55x9",
            ])
        #expect(
            data.sessions.map(\.title) == [
                "Göğüs (Chest)", "Göğüs (Chest)", "Göğüs (Chest) & Triceps (Arka Kol)", "Göğüs (Chest)", "Sırt (Back)",
                "Sırt (Back)",
            ])
        #expect(issues.isEmpty)
    }

    @Test func widePairsRepeatTheDateAndWorkoutAbove() throws {
        let (data, _) = try converted("wide-pairs.csv")
        #expect(
            summary(data) == [
                "2026-09-28 | Dumbbell Chest Press: 27.5x9, 22.5x13 | Incline Dumbbell Curl: 15x9, 12.5x9",
                "2026-09-30 | Lat Pulldown: 60x8, 55x9",
            ])
        #expect(data.sessions.map(\.title) == ["Chest & Biceps", "Back & Triceps"])
    }

    @Test func setNumbersOrderTheSets() throws {
        let (data, _) = try converted("us-long.csv")
        #expect(summary(data) == ["2026-09-28 | Bench Press: 155x5, 135x8", "2026-09-30 | Squat: 185x5"])
        #expect(data.units?.weight == .lb && data.sessions[0].note == "felt heavy")
    }

    @Test func setCellsWithTargets() throws {
        let (data, _) = try converted("sets.tsv")
        #expect(summary(data) == ["undated | Fly: 50x7, 45x9:8 | Row: 27.5x9"])
    }

    @Test func unreadableCellsAreWarningsWithTheirPlace() throws {
        let (data, issues) = try converted("workbook.xlsx")
        #expect(summary(data) == ["2026-09-28 | Dumbell Chest Press: 27.5x9 | Row: 0x13"])
        #expect(issues == [ImportIssue(.unreadableCell("#N/A"), at: "Antrenman!C5")])
    }

    /// A block sheet goes through the importer: undated sessions are placed before the first dated one.
    @MainActor
    @Test func blockHistoryImports() throws {
        let context = try makeContext()
        let (data, _) = try converted("block.csv")
        let importer = PeakImporter(context: context)
        let preview = try importer.preview(data)
        #expect(preview.canImport && preview.newSessions == 6 && preview.duplicateSessions == 0)
        #expect(preview.dateRange?.lowerBound.description == "2026-09-04")
        try importer.commit(data)
        #expect(try importer.preview(data).duplicateSessions == 6)
        let names = try ExerciseRepository(context: context).all().map(\.name).sorted()
        #expect(
            names == ["Dumbell Chest Press", "Lat Pulldown", "V Bar Triceps Pushdown", "İncline Smith Machine Press"])
    }
}
