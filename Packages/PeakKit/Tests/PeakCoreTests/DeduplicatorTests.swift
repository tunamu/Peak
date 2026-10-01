import Foundation
import PeakCore
import SwiftData
import Testing

/// F8-02: two devices that each created the same records end up with one of each, and agree on which one.
@MainActor
@Suite struct DeduplicatorTests {
    /// What a second device's sample program looks like once iCloud has brought it over: the same names in new
    /// records with their own ids.
    func installSecondDeviceCopy(into context: ModelContext) throws {
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        var copies: [UUID: Exercise] = [:]
        for exercise in exercises {
            let copy = Exercise(name: exercise.name)
            copy.muscleGroup = exercise.muscleGroup
            context.insert(copy)
            copies[exercise.id] = copy
        }
        var templateCopies: [UUID: WorkoutTemplate] = [:]
        for template in try context.fetch(FetchDescriptor<WorkoutTemplate>()) {
            let copy = WorkoutTemplate(name: template.name)
            context.insert(copy)
            copy.items = template.orderedItems.map { item in
                let exercise = item.exercise.flatMap { copies[$0.id] }
                return TemplateItem(order: item.order, targetSets: item.targetSets, exercise: exercise)
            }
            templateCopies[template.id] = copy
        }
        for routine in try context.fetch(FetchDescriptor<Routine>()) {
            let copy = Routine(name: routine.name)
            copy.weekdaysMask = routine.weekdaysMask
            context.insert(copy)
            copy.entries = routine.orderedEntries.map {
                RoutineEntry(order: $0.order, template: $0.template.flatMap { templateCopies[$0.id] })
            }
        }
        try context.save()
    }

    func count<Model: PersistentModel>(_: Model.Type, in context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<Model>())
    }

    @Test func sampleProgramOnTwoDevicesBecomesOne() throws {
        let context = try makeContext()
        try SampleProgram.install(into: context)
        let before = (
            exercises: try count(Exercise.self, in: context),
            templates: try count(WorkoutTemplate.self, in: context),
            items: try count(TemplateItem.self, in: context),
            entries: try count(RoutineEntry.self, in: context)
        )
        try installSecondDeviceCopy(into: context)
        #expect(try count(WorkoutTemplate.self, in: context) == before.templates * 2)

        let result = try Deduplicator.run(in: context)

        #expect(result == .init(exercises: before.exercises, templates: before.templates, routines: 1))
        #expect(try count(Exercise.self, in: context) == before.exercises)
        #expect(try count(WorkoutTemplate.self, in: context) == before.templates)
        #expect(try count(Routine.self, in: context) == 1)
        // The duplicates' own items and entries went with them; what is left points at survivors.
        #expect(try count(TemplateItem.self, in: context) == before.items)
        #expect(try count(RoutineEntry.self, in: context) == before.entries)
        let survivors = Set(try context.fetch(FetchDescriptor<Exercise>()).map(\.id))
        for item in try context.fetch(FetchDescriptor<TemplateItem>()) {
            #expect(item.exercise.map { survivors.contains($0.id) } == true)
        }
        #expect(try Deduplicator.run(in: context).total == 0)
    }

    @Test func theOldestSurvivesAndKeepsTheHistory() throws {
        let context = try makeContext()
        // The movement the user has had for weeks, with their increment, and a fresh copy from another device.
        let original = Exercise(name: "Row")
        original.id = try #require(UUID(uuidString: "FFFFFFFF-0000-0000-0000-000000000001"))
        original.incrementKg = 5
        original.createdAt = Date(timeIntervalSince1970: 1_790_000_000)
        let copy = Exercise(name: " row ")
        copy.id = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        context.insert(copy)
        context.insert(original)
        let template = try TemplateRepository(context: context).create(name: "Back")
        TemplateRepository(context: context).setItems([(copy, 3)], of: template)
        let sessions = SessionRepository(context: context)
        sessions.complete(sessions.start(from: template))
        try context.save()

        #expect(try Deduplicator.run(in: context).exercises == 1)

        let rows = try context.fetch(FetchDescriptor<Exercise>())
        #expect(rows.map(\.id) == [original.id])
        #expect(rows.first?.incrementKg == 5)
        #expect(template.orderedItems.first?.exercise?.id == original.id)
        #expect(try sessions.completed().first?.orderedExercises.first?.exercise?.id == original.id)
        #expect(try sessions.history(of: original).count == 1)
    }

    /// Within one second the smallest id wins, so a date that lost its last digits on the way through CloudKit
    /// cannot make two devices disagree.
    @Test func withinASecondTheSmallestIDSurvives() throws {
        let context = try makeContext()
        let second = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let low = Exercise(name: "Fly")
        low.id = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        low.createdAt = second.addingTimeInterval(0.9)
        let high = Exercise(name: "Fly")
        high.id = try #require(UUID(uuidString: "FFFFFFFF-0000-0000-0000-000000000001"))
        high.createdAt = second.addingTimeInterval(0.1)
        context.insert(high)
        context.insert(low)
        try context.save()

        try Deduplicator.run(in: context)
        #expect(try context.fetch(FetchDescriptor<Exercise>()).map(\.id) == [low.id])
    }

    @Test func anActiveCopyKeepsTheSurvivorActive() throws {
        let context = try makeContext()
        let archived = Exercise(name: "Fly")
        archived.createdAt = Date(timeIntervalSince1970: 1_790_000_000)
        archived.isArchived = true
        context.insert(archived)
        context.insert(Exercise(name: "Fly"))
        try context.save()

        try Deduplicator.run(in: context)
        #expect(try context.fetch(FetchDescriptor<Exercise>()).map(\.isArchived) == [false])
    }

    @Test func templatesWithTheSameNameButOtherExercisesBothStay() throws {
        let context = try makeContext()
        let exercises = ExerciseRepository(context: context)
        let templates = TemplateRepository(context: context)
        let first = try templates.create(name: "Push")
        templates.setItems([(try exercises.findOrCreate(name: "Fly"), 2)], of: first)
        let second = try templates.create(name: "Push")
        templates.setItems([(try exercises.findOrCreate(name: "Row"), 2)], of: second)
        try context.save()

        #expect(try Deduplicator.run(in: context).total == 0)
        #expect(try count(WorkoutTemplate.self, in: context) == 2)
    }

    @Test func routinesWithAnotherScheduleBothStay() throws {
        let context = try makeContext()
        let routines = RoutineRepository(context: context)
        try routines.create(name: "Main", weekdays: [.monday], templates: [])
        try routines.create(name: "Main", weekdays: [.tuesday], templates: [])
        try context.save()

        #expect(try Deduplicator.run(in: context).routines == 0)
    }

    @Test func aDuplicateRoutinesSessionsMoveToTheSurvivor() throws {
        let context = try makeContext()
        let template = try TemplateRepository(context: context).create(name: "Legs")
        let routines = RoutineRepository(context: context)
        let one = try routines.create(name: "Main", weekdays: [.monday], templates: [template])
        let other = try routines.create(name: "Main", weekdays: [.monday], templates: [template])
        let sessions = SessionRepository(context: context)
        sessions.complete(sessions.start(from: template, routine: one))
        sessions.complete(sessions.start(from: template, routine: other))
        try context.save()

        #expect(try Deduplicator.run(in: context).routines == 1)
        let survivor = try #require(try context.fetch(FetchDescriptor<Routine>()).first)
        #expect(survivor.id == one.id || survivor.id == other.id)
        let completed = try sessions.completed()
        #expect(completed.count == 2)
        #expect(completed.allSatisfy { $0.routine?.id == survivor.id })
    }

    /// Copies of one record (the same id, such as one export imported on two devices) cannot be told apart the same
    /// way everywhere, so none is deleted: two devices could otherwise each delete a different one and lose both.
    @Test func copiesWithTheSameIDAreLeftAlone() throws {
        let context = try makeContext()
        let id = UUID()
        for _ in 0..<2 {
            let exercise = Exercise(name: "Row")
            exercise.id = id
            context.insert(exercise)
        }
        try context.save()

        #expect(try Deduplicator.run(in: context).total == 0)
        #expect(try count(Exercise.self, in: context) == 2)
    }

    @Test func sessionsAndWaterAreNeverMerged() throws {
        let context = try makeContext()
        let template = try TemplateRepository(context: context).create(name: "Legs")
        let sessions = SessionRepository(context: context)
        let day = Date(timeIntervalSince1970: 1_790_000_000)
        sessions.complete(sessions.start(from: template, at: day), at: day.addingTimeInterval(600))
        sessions.complete(sessions.start(from: template, at: day), at: day.addingTimeInterval(600))
        context.insert(WaterLog(amountMl: 500, date: day))
        context.insert(WaterLog(amountMl: 500, date: day))
        try context.save()

        #expect(try Deduplicator.run(in: context).total == 0)
        #expect(try count(WorkoutSession.self, in: context) == 2)
        #expect(try count(WaterLog.self, in: context) == 2)
    }
}
