import Foundation
import PeakCore
import SwiftData
import Testing

/// F7-02: export → import into an empty store → export gives the same file, and the importer's basic rules.
/// Merge, duplicates, undated sessions and validation: `PeakImporterTests` (F7-03).
@MainActor
@Suite struct PeakRoundTripTests {
    let now = Date(timeIntervalSinceReferenceDate: 812_000_000.123_456)  // 2026-09-25, with a fraction

    /// A store with a bit of everything: the sample program and history, a second routine on an interval, a renamed
    /// exercise, an archived template, a paused workout, a walk, water and a Health id.
    func filledStore() throws -> ModelContext {
        let context = try makeContext()
        try SampleProgram.install(into: context)
        try SampleProgram.installHistory(into: context, now: now)
        try SampleProgram.installSecondRoutine(into: context, now: now)

        let exercises = try ExerciseRepository(context: context).all()
        exercises[0].name += " (renamed)"
        let templates = try TemplateRepository(context: context).all()
        TemplateRepository(context: context).archive(templates[5])
        try SessionRepository(context: context).completed().first?.healthKitWorkoutID = UUID()

        let sessions = SessionRepository(context: context)
        let running = sessions.start(from: templates[0], at: now.addingTimeInterval(3_600))
        let controller = WorkoutSessionController(session: running, context: context)
        let set = try #require(running.orderedExercises.first?.orderedSets.first)
        try controller.setWeight(27.5, of: set)
        try controller.setReps(9, of: set, at: now.addingTimeInterval(3_700))
        try controller.pause(at: now.addingTimeInterval(3_800))
        running.note = "Left for a call"

        let walking = try TemplateRepository(context: context).create(name: "Walking", kind: .cardio)
        let walk = try ExerciseRepository(context: context).findOrCreate(name: "Incline Walk", kind: .cardio)
        TemplateRepository(context: context).setItems([(walk, 1)], of: walking)
        let walkSession = sessions.start(from: walking, at: now.addingTimeInterval(-86_400))
        let segment = try #require(walkSession.orderedExercises.first?.orderedSegments.first)
        segment.speedKmh = 5.5
        segment.inclinePercent = 12
        segment.durationSec = 1_830
        _ = try WorkoutSessionController(session: walkSession, context: context)
            .addSegment(to: #require(walkSession.orderedExercises.first))
        sessions.complete(walkSession, at: now.addingTimeInterval(-84_000))

        let water = WaterRepository(context: context)
        _ = try water.add(500, at: now)
        _ = try water.remove(200, at: now.addingTimeInterval(60), source: .widget)
        try context.save()
        return context
    }

    func settings() throws -> SettingsStore {
        SettingsStore(defaults: try #require(UserDefaults(suiteName: "peak.tests.\(UUID().uuidString)")))
    }

    func exportedJSON(_ context: ModelContext, settings: SettingsStore) throws -> Data {
        try PeakJSON.encode(PeakExporter(context: context).export(settings: settings.transferSettings, at: now))
    }

    @Test func exportThenImportIntoAnEmptyStoreGivesTheSameFile() throws {
        let original = try settings()
        original.stepGoal = 12_000
        original.overloadThresholdReps = 10
        original.unitSystem = .imperial
        let first = try exportedJSON(filledStore(), settings: original)

        let copy = try makeContext()
        let copySettings = try settings()
        let data = try PeakJSON.decode(first)
        let summary = try PeakImporter(context: copy).commit(data)
        copySettings.apply(try #require(data.settings))
        let second = try exportedJSON(copy, settings: copySettings)

        #expect(String(bytes: second, encoding: .utf8) == String(bytes: first, encoding: .utf8))
        #expect(summary.sessions == data.sessions.count)
        #expect(summary.exercises == data.exercises?.count)
        #expect(copySettings.stepGoal == 12_000 && copySettings.unitSystem == .imperial)
    }

    @Test func importKeepsIdsAndLinks() throws {
        let context = try filledStore()
        let data = try PeakExporter(context: context).export(settings: nil)
        let copy = try makeContext()
        try PeakImporter(context: copy).commit(data)

        let before = try context.fetch(FetchDescriptor<WorkoutSession>()).sorted { $0.startedAt < $1.startedAt }
        let after = try copy.fetch(FetchDescriptor<WorkoutSession>()).sorted { $0.startedAt < $1.startedAt }
        #expect(after.map(\.id) == before.map(\.id))
        #expect(after.map { $0.template?.id } == before.map { $0.template?.id })
        #expect(after.map { $0.routine?.id } == before.map { $0.routine?.id })
        // The renamed exercise: sessions keep the old name, linked to the same exercise.
        let names = { (sessions: [WorkoutSession]) in
            sessions.flatMap { $0.orderedExercises.map { "\($0.exerciseName)|\($0.exercise?.name ?? "-")" } }
        }
        #expect(names(after) == names(before))
        #expect(try SessionRepository(context: copy).current()?.status == .paused)
    }

    @Test func exportedFileMatchesTheSchema() throws {
        let validator = try JSONSchemaValidator(
            schema: Data(
                contentsOf: PeakJSONSchemaTests.schemaFolder.appending(path: "peak-workout-data.v1.schema.json")))
        let json = try exportedJSON(filledStore(), settings: settings())
        #expect(try validator.errors(in: json) == [])
    }

    @Test func emptyStoreExportsAnEmptyFile() throws {
        let data = try PeakExporter(context: makeContext()).export(settings: nil, at: now)
        #expect(data.sessions.isEmpty && data.exercises == [] && data.waterLogs == [])
        #expect(data.schema == "peak.workout-data" && data.schemaVersion == 1)
    }

    @Test func fileNameHasTheDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Istanbul"))
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: 23)))
        #expect(PeakExporter.fileName(on: date, calendar: calendar) == "peak-export-2026-09-30.json")
    }

    // MARK: Importer rules

    /// A file with one session on 28.09.2026 holding one set of "Row".
    func oneSet(_ set: String, units: String = "kg") -> String {
        #"{ "units": { "weight": "\#(units)" }, "sessions": [ { "date": "2026-09-28", "exercises": [ "#
            + #"{ "exerciseName": "Row", "sets": [ \#(set) ] } ] } ] }"#
    }

    func imported(_ json: String) throws -> ModelContext {
        let context = try makeContext()
        try PeakImporter(context: context).commit(PeakJSON.decode(Data(json.utf8)))
        return context
    }

    @Test func aDateOnlySessionGetsDefaults() throws {
        let context = try imported(oneSet(#"{ "weight": 60, "reps": 8 }"#))
        let session = try #require(try context.fetch(FetchDescriptor<WorkoutSession>()).first)
        #expect(Calendar.current.component(.hour, from: session.startedAt) == 12)
        #expect(session.endedAt == session.startedAt && session.duration() == 0)
        #expect(session.status == .completed && session.source == .importJSON)
        #expect(session.orderedExercises.first?.orderedSets.first?.isCompleted == true)
    }

    @Test func poundsAreStoredAsKilograms() throws {
        let context = try imported(oneSet(#"{ "weight": 135, "reps": 8, "targetWeight": 135 }"#, units: "lb"))
        let set = try #require(try context.fetch(FetchDescriptor<SetEntry>()).first)
        #expect(abs(set.weightKg - 61.235) < 0.001)
        #expect(set.targetWeightKg == set.weightKg)
    }

    @Test func exercisesAreFoundByIdThenNameElseCreated() throws {
        let context = try makeContext()
        _ = try ExerciseRepository(context: context).findOrCreate(name: "Incline Dumbbell Curl")
        let json = #"""
            { "exercises": [ { "id": "row", "name": "Seated Row", "equipment": "cable" } ],
              "sessions": [ { "date": "2026-09-28", "exercises": [
                { "exerciseId": "row" },
                { "exerciseId": "missing", "exerciseName": "seated  ROW" },
                { "exerciseName": "İncline Dumbbell Curl" },
                { "exerciseName": "Face Pull" },
                { "exerciseName": "face pull" }
              ] } ] }
            """#
        try PeakImporter(context: context).commit(PeakJSON.decode(Data(json.utf8)))

        let names = try ExerciseRepository(context: context).all().map(\.name).sorted()
        #expect(names == ["Face Pull", "Incline Dumbbell Curl", "Seated Row"])
        let session = try #require(try context.fetch(FetchDescriptor<WorkoutSession>()).first)
        #expect(
            session.orderedExercises.map { $0.exercise?.name } == [
                "Seated Row", "Seated Row", "Incline Dumbbell Curl", "Face Pull", "Face Pull",
            ])
        // The snapshot keeps the file's spelling.
        #expect(session.orderedExercises[2].exerciseName == "İncline Dumbbell Curl")
    }
}
