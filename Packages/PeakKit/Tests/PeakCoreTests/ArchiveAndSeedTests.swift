import Foundation
import PeakCore
import SwiftData
import Testing

/// F2-06: archiving and deleting never damage history.
@MainActor
@Suite struct ArchiveBehaviorTests {
    @Test func archivedExerciseStillShowsInHistoryByName() throws {
        let context = try makeContext()
        let exercises = ExerciseRepository(context: context)
        let templates = TemplateRepository(context: context)
        let sessions = SessionRepository(context: context)
        let press = try exercises.findOrCreate(name: "Dumbbell Chest Press")
        let template = try templates.create(name: "Chest & Biceps")
        templates.setItems([(press, 2)], of: template)
        let session = sessions.start(from: template)
        session.orderedExercises.first?.orderedSets.first?.weightKg = 27.5
        sessions.complete(session)
        try context.save()

        exercises.archive(press)
        templates.archive(template)
        try context.save()

        let history = try sessions.history(of: press)
        #expect(history.count == 1)
        #expect(history.first?.exerciseName == "Dumbbell Chest Press")
        #expect(history.first?.orderedSets.first?.weightKg == 27.5)
        #expect(try sessions.completed().first?.template?.name == "Chest & Biceps")
    }

    @Test func renamingKeepsTheSnapshot() throws {
        let context = try makeContext()
        let exercises = ExerciseRepository(context: context)
        let templates = TemplateRepository(context: context)
        let sessions = SessionRepository(context: context)
        let press = try exercises.findOrCreate(name: "Dumbell Chest Press")
        let template = try templates.create(name: "Chest")
        templates.setItems([(press, 2)], of: template)
        sessions.complete(sessions.start(from: template))
        try context.save()

        press.name = "Dumbbell Chest Press"
        template.name = "Chest Day"
        try context.save()

        let session = try #require(try sessions.completed().first)
        #expect(session.title == "Chest")
        #expect(session.orderedExercises.first?.exerciseName == "Dumbell Chest Press")
        #expect(try sessions.history(of: press).count == 1)
    }

    @Test func templateItemsGoWhenTheirTemplateIsDeletedButExercisesStay() throws {
        let context = try makeContext()
        let templates = TemplateRepository(context: context)
        let template = try templates.create(name: "A")
        templates.setItems([(try ExerciseRepository(context: context).findOrCreate(name: "Row"), 2)], of: template)
        try context.save()

        context.delete(template)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<TemplateItem>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Exercise>()) == 1)
    }
}

/// F2-05: the sample program.
@MainActor
@Suite struct SampleProgramTests {
    @Test func installsSixTemplatesAndOneRoutine() throws {
        let context = try makeContext()
        try SampleProgram.install(into: context)

        let templates = try TemplateRepository(context: context).all()
        #expect(
            templates.map(\.name) == [
                "Chest & Biceps", "Back & Triceps", "Shoulder & Biceps",
                "Chest & Triceps", "Back & Biceps", "Shoulder & Triceps",
            ])
        #expect(templates.allSatisfy { $0.orderedItems.count == 5 })
        #expect(try ExerciseRepository(context: context).all().count == 13)

        let routine = try #require(try RoutineRepository(context: context).active().first)
        #expect(routine.weekdays == [.monday, .wednesday, .friday])
        #expect(routine.orderedEntries.compactMap(\.template?.name) == templates.map(\.name))

        let row = templates[1].orderedItems.first { $0.exercise?.name == "Row" }
        #expect(row?.targetSets == 3)
        #expect(row?.exercise?.incrementKg == 5)
    }

    @Test func installingTwiceAddsNothing() throws {
        let context = try makeContext()
        try SampleProgram.install(into: context)
        try SampleProgram.install(into: context)
        #expect(try context.fetchCount(FetchDescriptor<WorkoutTemplate>()) == 6)
        #expect(try context.fetchCount(FetchDescriptor<Exercise>()) == 13)
        #expect(try context.fetchCount(FetchDescriptor<Routine>()) == 1)
    }
}
