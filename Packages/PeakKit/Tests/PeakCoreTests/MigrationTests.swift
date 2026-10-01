import Foundation
import PeakCore
import SwiftData
import Testing

/// F11: a store written with `SchemaV1` (as on devices before F11) opens with the app's migration plan as `SchemaV2`,
/// with every record in place and the new properties at their defaults.
@MainActor
@Suite struct MigrationTests {
    @Test func aVersionOneStoreOpensAsVersionTwo() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "PeakMigration-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "Peak.store")

        try writeVersionOne(at: url)

        let container = try PeakStore.makeContainer(.file(url))
        let context = container.mainContext
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let templates = try context.fetch(FetchDescriptor<WorkoutTemplate>())
        let routines = try context.fetch(FetchDescriptor<Routine>())
        let sessions = try SessionRepository(context: context).completed()
        #expect(exercises.map(\.name) == ["Row"])
        #expect(templates.map(\.name) == ["Back"] && templates.first?.orderedItems.first?.targetSets == 3)
        #expect(routines.first?.orderedEntries.first?.template?.name == "Back")
        let session = try #require(sessions.first)
        #expect(sessions.count == 1 && session.title == "Back" && session.note == "Felt strong")
        let movement = try #require(session.orderedExercises.first)
        #expect(
            movement.orderedSets.map { SetPerformance(weightKg: $0.weightKg, reps: $0.reps) } == sets("60x10, 60x8"))
        #expect(movement.exercise?.name == "Row")
        // The new properties start empty, so nothing changes until the user sets them.
        #expect(movement.note.isEmpty)
        let exercise = try #require(exercises.first)
        #expect(exercise.note.isEmpty && exercise.overloadThresholdReps == nil && exercise.overloadRepStep == nil)
        #expect(templates.first?.overloadResetReps == nil)

        // And it keeps working: a new session with a note saves and reads back.
        movement.note = "Seat 4"
        try context.save()
        #expect(try SessionRepository(context: context).completed().first?.orderedExercises.first?.note == "Seat 4")
    }

    /// A store as a pre-F11 build leaves it: one exercise, template, routine and completed session.
    private func writeVersionOne(at url: URL) throws {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let container = try ModelContainer(
            for: schema, configurations: ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none))
        let context = container.mainContext
        let exercise = SchemaV1.Exercise(name: "Row")
        let template = SchemaV1.WorkoutTemplate(name: "Back")
        let item = SchemaV1.TemplateItem(order: 0, targetSets: 3, exercise: exercise)
        let routine = SchemaV1.Routine(name: "Main")
        let entry = SchemaV1.RoutineEntry(order: 0, template: template)
        let session = SchemaV1.WorkoutSession(title: "Back")
        let movement = SchemaV1.SessionExercise(order: 0, exercise: exercise)
        let first = SchemaV1.SetEntry(order: 0, weightKg: 60, reps: 10)
        let second = SchemaV1.SetEntry(order: 1, weightKg: 60, reps: 8)
        for model in [exercise, template, item, routine, entry, session, movement, first, second]
            as [any PersistentModel]
        {
            context.insert(model)
        }
        item.template = template
        entry.routine = routine
        session.template = template
        session.routine = routine
        session.statusRaw = SessionStatus.completed.rawValue
        session.endedAt = session.startedAt.addingTimeInterval(3_600)
        session.note = "Felt strong"
        movement.session = session
        first.sessionExercise = movement
        second.sessionExercise = movement
        try context.save()
    }
}
