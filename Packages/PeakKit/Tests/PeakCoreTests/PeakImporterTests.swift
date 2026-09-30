import Foundation
import PeakCore
import SwiftData
import Testing

/// F7-03: validation, merge and duplicates, undated sessions, replace with a backup.
@MainActor
@Suite struct PeakImporterTests {
    let now = Date(timeIntervalSinceReferenceDate: 812_450_000)  // 2026-09-30 08:33 UTC

    /// A session with one set of "Row"; `fields` go before its exercises (`"date": "2026-09-28",`).
    nonisolated static func row(_ fields: String = "", reps: Int = 8) -> String {
        #"{ \#(fields) "exercises": [ { "exerciseName": "Row", "sets": [ { "weight": 60, "reps": \#(reps) } ] } ] }"#
    }

    nonisolated static func dated(_ date: String, reps: Int = 8) -> String {
        row(#""date": "\#(date)","#, reps: reps)
    }

    nonisolated static func sessions(_ items: String...) -> String {
        #"{ "sessions": [ \#(items.joined(separator: ", ")) ] }"#
    }

    func file(_ json: String) throws -> PeakExportV1 {
        try PeakJSON.decode(Data(json.utf8))
    }

    func example(_ name: String) throws -> PeakExportV1 {
        try PeakJSON.decode(PeakJSONSchemaTests.example(name))
    }

    func counts(_ context: ModelContext) throws -> [Int] {
        [
            try context.fetchCount(FetchDescriptor<Exercise>()),
            try context.fetchCount(FetchDescriptor<WorkoutTemplate>()),
            try context.fetchCount(FetchDescriptor<Routine>()),
            try context.fetchCount(FetchDescriptor<WorkoutSession>()),
            try context.fetchCount(FetchDescriptor<SetEntry>()),
            try context.fetchCount(FetchDescriptor<WaterLog>()),
        ]
    }

    func sessions(_ context: ModelContext) throws -> [WorkoutSession] {
        try context.fetch(FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\.startedAt)]))
    }

    // MARK: Duplicates

    /// The acceptance criterion: the same file imported twice adds nothing the second time.
    @Test(arguments: PeakJSONSchemaTests.examples)
    func theSameFileTwiceAddsNothingTheSecondTime(_ name: String) throws {
        let context = try makeContext()
        let importer = PeakImporter(context: context, now: now)
        try importer.commit(example(name))
        let before = try counts(context)

        let preview = try importer.preview(example(name))
        #expect(preview.newSessions == 0 && preview.duplicateSessions == preview.sessions)
        #expect(preview.newExercises.isEmpty && preview.newTemplates == 0 && preview.newRoutines == 0)
        #expect(preview.newWaterLogs == 0)
        let summary = try importer.commit(example(name))
        #expect(summary.sessions == 0 && summary.exercises == 0)
        #expect(try counts(context) == before)
    }

    /// Undated sessions are found again on a later day, although their estimated date would differ.
    @Test func undatedSessionsAreFoundAgainOnAnotherDay() throws {
        let context = try makeContext()
        let json = Self.sessions(Self.row())
        try PeakImporter(context: context, now: now).commit(file(json))
        let later = PeakImporter(context: context, now: now.addingTimeInterval(7 * 86_400))
        #expect(try later.preview(file(json)).duplicateSessions == 1)
        try later.commit(file(json))
        #expect(try sessions(context).count == 1)
    }

    /// Exporting a store and importing the file back into it adds nothing.
    @Test func importingAnExportIntoTheSameStoreAddsNothing() throws {
        let context = try makeContext()
        try SampleProgram.install(into: context)
        try SampleProgram.installHistory(into: context, now: now)
        let before = try counts(context)
        let data = try PeakExporter(context: context).export(settings: nil)
        #expect(try PeakImporter(context: context).commit(data) == PeakImportSummary())
        #expect(try counts(context) == before)
    }

    @Test func aSessionIsADuplicateByContentNotOnlyById() throws {
        let context = try makeContext()
        let importer = PeakImporter(context: context)
        try importer.commit(file(Self.sessions(Self.dated("2026-09-28"))))
        let preview = try importer.preview(
            file(Self.sessions(Self.dated("2026-09-28"), Self.dated("2026-09-28", reps: 9), Self.dated("2026-09-29"))))
        #expect(preview.duplicateSessions == 1 && preview.newSessions == 2)
    }

    /// Two identical sessions in a file are both new the first time and both duplicates the second.
    @Test func identicalSessionsInOneFileCountOneByOne() throws {
        let context = try makeContext()
        let json = Self.sessions(Self.dated("2026-09-28"), Self.dated("2026-09-28"))
        let importer = PeakImporter(context: context)
        try importer.commit(file(json))
        #expect(try sessions(context).count == 2)
        try importer.commit(file(json))
        #expect(try sessions(context).count == 2)
    }

    // MARK: Merge

    @Test func existingRecordsWinAndAreMatchedByName() throws {
        let context = try makeContext()
        try SampleProgram.install(into: context)
        let press = try #require(try ExerciseRepository(context: context).find(named: "Dumbbell Chest Press"))
        let json = #"""
            { "exercises": [ { "name": "dumbbell chest press", "incrementKg": 10 } ],
              "workoutTemplates": [ { "name": "chest & biceps", "items": [ { "exerciseName": "Pec Deck" } ] } ],
              "sessions": [ { "date": "2026-09-28", "exercises": [
                { "exerciseName": "DUMBBELL chest press", "sets": [ { "weight": 27.5, "reps": 9 } ] } ] } ] }
            """#
        let before = try counts(context)
        let preview = try PeakImporter(context: context).preview(file(json))
        #expect(preview.newExercises.isEmpty && preview.newTemplates == 0)
        try PeakImporter(context: context).commit(file(json))

        #expect(press.incrementKg == 2.5)
        #expect(try counts(context)[0...2] == before[0...2])
        #expect(try sessions(context).first?.orderedExercises.first?.exercise === press)
    }

    @Test func previewListsWhatIsNewWithoutWriting() throws {
        let context = try makeContext()
        let preview = try PeakImporter(context: context, now: now).preview(example("minimal.json"))
        #expect(preview.sessions == 2 && preview.newSessions == 2 && preview.newSets == 5)
        #expect(preview.newExercises == ["Dumbell Chest Press", "İncline Dumbell Curl"])
        #expect(
            preview.dateRange == LocalDate(year: 2026, month: 9, day: 27)...LocalDate(year: 2026, month: 9, day: 28))
        #expect(!preview.hasSettings && preview.canImport)
        #expect(try counts(context) == [0, 0, 0, 0, 0, 0])
    }

    // MARK: Undated sessions

    @Test func undatedSessionsGoBeforeTheEarliestDatedOne() throws {
        let context = try makeContext()
        let session = { (fields: String) in
            #"{ \#(fields) "exercises": [ { "exerciseName": "Row", "sets": [ { "weight": 60, "reps": 8 } ] } ] }"#
        }
        let json = #"""
            { "sessions": [ \#(session("")), \#(session(#""date": "2026-09-28","#)), \#(session("")),
              \#(session(#""date": "2026-09-20","#)), \#(session("")) ] }
            """#
        let preview = try PeakImporter(context: context).preview(file(json))
        let estimated = preview.warnings.compactMap { issue -> LocalDate? in
            if case .estimatedDate(let day) = issue.kind { day } else { nil }
        }
        #expect(estimated.map(\.description) == ["2026-09-17", "2026-09-18", "2026-09-19"])
        #expect(preview.warnings.map(\.path) == ["sessions[0]", "sessions[2]", "sessions[4]"])

        try PeakImporter(context: context).commit(file(json))
        let stored = try sessions(context)
        #expect(stored.map(\.isDateEstimated) == [true, true, true, false, false])
        #expect(stored.allSatisfy { Calendar.current.component(.hour, from: $0.startedAt) == 12 })
    }

    @Test func withoutDatedSessionsUndatedOnesEndYesterday() throws {
        let context = try makeContext()
        let one = #"{ "exercises": [ { "exerciseName": "Row", "sets": [ { "weight": 60, "reps": 8 } ] } ] }"#
        let preview = try PeakImporter(context: context, now: now).preview(file(#"{ "sessions": [ \#(one) ] }"#))
        let yesterday = try #require(Calendar.current.date(byAdding: .day, value: -1, to: now))
        #expect(preview.dateRange?.upperBound == LocalDate(yesterday))
    }

    // MARK: Validation

    @Test(arguments: [
        (#"{ "schema": "other", "sessions": [] }"#, ImportIssue(.notPeakData("other"), at: "schema")),
        (#"{ "schemaVersion": 2, "sessions": [] }"#, ImportIssue(.unsupportedVersion(2), at: "schemaVersion")),
        (
            #"{ "exercises": [ { "name": "  " } ], "sessions": [] }"#,
            ImportIssue(.blankName, at: "exercises[0].name")
        ),
        (
            #"{ "exercises": [ { "name": "Row", "incrementKg": -1 } ], "sessions": [] }"#,
            ImportIssue(.outOfRange(field: "incrementKg"), at: "exercises[0].incrementKg")
        ),
        (
            #"{ "routines": [ { "name": "A", "schedule": { "type": "weekdays", "days": [] } } ], "sessions": [] }"#,
            ImportIssue(.noWeekdays, at: "routines[0].schedule.days")
        ),
        (
            sessions(dated("2026-09-28", reps: -2)),
            ImportIssue(.outOfRange(field: "reps"), at: "sessions[0].exercises[0].sets[0].reps")
        ),
        (
            #"{ "sessions": [ { "date": "2026-09-28", "exercises": [ { "sets": [] } ] } ] }"#,
            ImportIssue(.missingExercise, at: "sessions[0].exercises[0]")
        ),
        (
            sessions(row(#""startedAt": "2026-09-28T18:00:00Z", "endedAt": "2026-09-28T17:00:00Z","#)),
            ImportIssue(.endsBeforeStart, at: "sessions[0].endedAt")
        ),
    ])
    func errorsBlockTheImport(_ json: String, _ issue: ImportIssue) throws {
        let context = try makeContext()
        let preview = try PeakImporter(context: context).preview(file(json))
        #expect(preview.errors == [issue])
        #expect(!preview.canImport)
        #expect(throws: PeakImportError.invalid([issue])) {
            try PeakImporter(context: context).commit(file(json))
        }
        #expect(try counts(context) == [0, 0, 0, 0, 0, 0])
    }

    @Test func unknownReferencesAreWarningsAndTheLinkIsLeftOut() throws {
        let context = try makeContext()
        let json = #"""
            { "routines": [ { "name": "A", "templateIds": ["ghost"] } ],
              "sessions": [ { "date": "2026-09-28", "templateId": "nope", "title": "Legs",
                "exercises": [ { "exerciseId": "lost" }, { "exerciseId": "lost-too", "exerciseName": "Squat" } ] } ] }
            """#
        let preview = try PeakImporter(context: context).preview(file(json))
        #expect(preview.canImport)
        #expect(
            preview.warnings == [
                ImportIssue(.unknownReference(field: "templateIds", id: "ghost"), at: "routines[0].templateIds[0]"),
                ImportIssue(.unknownReference(field: "templateId", id: "nope"), at: "sessions[0].templateId"),
                ImportIssue(
                    .unknownReference(field: "exerciseId", id: "lost"), at: "sessions[0].exercises[0].exerciseId"),
            ])
        try PeakImporter(context: context).commit(file(json))
        let session = try #require(try sessions(context).first)
        #expect(session.template == nil && session.title == "Legs")
        #expect(session.orderedExercises.map { $0.exercise?.name } == [nil, "Squat"])
    }

    // MARK: Replace all

    @Test func replaceAllWritesABackupFirst() throws {
        let context = try makeContext()
        try SampleProgram.install(into: context)
        try SampleProgram.installHistory(into: context, now: now)
        let before = try PeakExporter(context: context).export(settings: nil, at: now)
        let folder = FileManager.default.temporaryDirectory.appending(path: "peak-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }

        let summary = try PeakImporter(context: context, now: now)
            .commit(example("minimal.json"), mode: .replaceAll(backupDirectory: folder))

        let backup = try #require(summary.backup)
        #expect(backup.lastPathComponent.hasPrefix("peak-backup-2026-09-"), "\(backup.lastPathComponent)")
        #expect(try Data(contentsOf: backup) == PeakJSON.encode(before))
        #expect(try counts(context) == [2, 0, 0, 2, 5, 0])
    }

    @Test func aFailedBackupLeavesTheStoreAlone() throws {
        let context = try makeContext()
        try SampleProgram.install(into: context)
        let before = try counts(context)
        // A file where the folder should be: the backup cannot be written.
        let blocker = FileManager.default.temporaryDirectory.appending(path: "peak-tests-\(UUID().uuidString)")
        try Data().write(to: blocker)
        defer { try? FileManager.default.removeItem(at: blocker) }

        #expect(throws: (any Error).self) {
            try PeakImporter(context: context).commit(
                example("minimal.json"), mode: .replaceAll(backupDirectory: blocker))
        }
        #expect(try counts(context) == before)
    }
}
