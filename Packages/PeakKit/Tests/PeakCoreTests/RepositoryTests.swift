import Foundation
import PeakCore
import SwiftData
import Testing

/// Containers made for tests, kept alive for the whole run: a `ModelContext` does not retain its container, so
/// returning only `mainContext` would leave it pointing at a freed container and crash on first use.
@MainActor private var testContainers: [ModelContainer] = []

/// A fresh, empty in-memory store for one test.
@MainActor
func makeContext() throws -> ModelContext {
    let container = try PeakStore.makeContainer(.inMemory)
    testContainers.append(container)
    return container.mainContext
}

@MainActor
@Suite struct ExerciseRepositoryTests {
    @Test func findOrCreateMatchesIgnoringCaseAndAccents() throws {
        let repository = ExerciseRepository(context: try makeContext())
        let first = try repository.findOrCreate(name: "İncline Walk")
        let second = try repository.findOrCreate(name: "  incline   WALK ")
        #expect(first === second)
        #expect(try repository.all().count == 1)
    }

    @Test func archivedAreHiddenButRevivedByFindOrCreate() throws {
        let repository = ExerciseRepository(context: try makeContext())
        let row = try repository.findOrCreate(name: "Row")
        repository.archive(row)
        #expect(try repository.all().isEmpty)
        #expect(try repository.all(includingArchived: true).count == 1)
        #expect(try repository.findOrCreate(name: "row") === row)
        #expect(!row.isArchived)
    }
}

@MainActor
@Suite struct TemplateRepositoryTests {
    @Test func itemsKeepTheirOrder() throws {
        let context = try makeContext()
        let exercises = ExerciseRepository(context: context)
        let templates = TemplateRepository(context: context)
        let names = ["Lat Pulldown", "Close Grip Pulldown", "Row", "V Bar Triceps Pushdown"]
        let template = try templates.create(name: "Back & Triceps")
        templates.setItems(try names.map { (try exercises.findOrCreate(name: $0), 2) }, of: template)
        try context.save()
        #expect(template.orderedItems.compactMap(\.exercise?.name) == names)

        templates.setItems(try names.reversed().map { (try exercises.findOrCreate(name: $0), 3) }, of: template)
        try context.save()
        #expect(template.orderedItems.compactMap(\.exercise?.name) == names.reversed())
        #expect(try context.fetchCount(FetchDescriptor<TemplateItem>()) == names.count)
    }

    @Test func newTemplatesGoLastAndReorderWorks() throws {
        let templates = TemplateRepository(context: try makeContext())
        let first = try templates.create(name: "A")
        let second = try templates.create(name: "B")
        #expect(try templates.all().map(\.name) == ["A", "B"])
        templates.reorder([second, first])
        #expect(try templates.all().map(\.name) == ["B", "A"])
    }
}

@MainActor
@Suite struct RoutineRepositoryTests {
    @Test func weekdayRoutineStoresDaysAndRotation() throws {
        let context = try makeContext()
        let templates = TemplateRepository(context: context)
        let routines = RoutineRepository(context: context)
        let rotation = try ["A", "B", "C"].map { try templates.create(name: $0) }
        let routine = try routines.create(name: "Main", weekdays: [.friday, .monday], templates: rotation)
        try context.save()
        #expect(routine.weekdays == [.monday, .friday])
        #expect(routine.weekdaysMask == 0b10001)
        #expect(routine.orderedEntries.compactMap(\.template?.name) == ["A", "B", "C"])
        #expect(try routines.active().count == 1)
    }

    @Test func deletingRoutineKeepsItsSessions() throws {
        let context = try makeContext()
        let template = try TemplateRepository(context: context).create(name: "A")
        let routines = RoutineRepository(context: context)
        let sessions = SessionRepository(context: context)
        let routine = try routines.create(name: "Main", weekdays: [.monday], templates: [template])
        sessions.complete(sessions.start(from: template, routine: routine))
        try context.save()

        routines.delete(routine)
        try context.save()
        let remaining = try sessions.completed()
        #expect(remaining.count == 1)
        #expect(remaining.first?.routine == nil)
        #expect(remaining.first?.title == "A")
        #expect(try context.fetchCount(FetchDescriptor<RoutineEntry>()) == 0)
    }
}

@MainActor
@Suite struct SessionRepositoryTests {
    @Test func startCopiesTemplateWithEmptySets() throws {
        let context = try makeContext()
        let exercises = ExerciseRepository(context: context)
        let templates = TemplateRepository(context: context)
        let template = try templates.create(name: "Back & Triceps")
        templates.setItems(
            [(try exercises.findOrCreate(name: "Row"), 3), (try exercises.findOrCreate(name: "Lat Pulldown"), 2)],
            of: template
        )
        let session = SessionRepository(context: context).start(from: template)
        try context.save()

        #expect(session.title == "Back & Triceps")
        #expect(session.status == .active)
        #expect(session.orderedExercises.map(\.exerciseName) == ["Row", "Lat Pulldown"])
        #expect(session.orderedExercises.map { $0.orderedSets.count } == [3, 2])
    }

    @Test func cardioExerciseGetsASegmentInsteadOfSets() throws {
        let context = try makeContext()
        let walk = try ExerciseRepository(context: context).findOrCreate(name: "Incline Walk", kind: .cardio)
        let templates = TemplateRepository(context: context)
        let template = try templates.create(name: "Walking", kind: .cardio)
        templates.setItems([(walk, 1)], of: template)
        let exercise = SessionRepository(context: context).start(from: template).orderedExercises.first
        #expect(exercise?.orderedSets.isEmpty == true)
        #expect(exercise?.orderedSegments.count == 1)
    }

    @Test func completeClosesAPauseAndDurationSubtractsIt() throws {
        let context = try makeContext()
        let template = try TemplateRepository(context: context).create(name: "A")
        let sessions = SessionRepository(context: context)
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let session = sessions.start(from: template, at: start)
        session.pausedTotal = 60
        session.pausedAt = start.addingTimeInterval(1_000)
        sessions.complete(session, at: start.addingTimeInterval(1_300))

        #expect(session.status == .completed)
        #expect(session.pausedAt == nil)
        #expect(session.pausedTotal == 360)
        #expect(session.duration() == 940)
    }

    @Test func currentAndLastCompleted() throws {
        let context = try makeContext()
        let templates = TemplateRepository(context: context)
        let first = try templates.create(name: "A")
        let second = try templates.create(name: "B")
        let routine = try RoutineRepository(context: context)
            .create(name: "Main", weekdays: [.monday], templates: [first, second])
        let sessions = SessionRepository(context: context)
        let day = Date(timeIntervalSinceReferenceDate: 0)

        sessions.complete(sessions.start(from: first, routine: routine, at: day), at: day.addingTimeInterval(60))
        let running = sessions.start(from: second, routine: routine, at: day.addingTimeInterval(86_400))
        try context.save()

        #expect(try sessions.current() === running)
        #expect(try sessions.lastCompleted(in: routine)?.title == "A")
    }

    @Test func discardDeletesTheWholeSession() throws {
        let context = try makeContext()
        let exercises = ExerciseRepository(context: context)
        let templates = TemplateRepository(context: context)
        let template = try templates.create(name: "A")
        templates.setItems([(try exercises.findOrCreate(name: "Row"), 3)], of: template)
        let sessions = SessionRepository(context: context)
        sessions.discard(sessions.start(from: template))
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<WorkoutSession>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<SessionExercise>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<SetEntry>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Exercise>()) == 1)
    }
}

@MainActor
@Suite struct WaterRepositoryTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    @Test func totalIsPerDayAndNeverNegative() throws {
        let water = WaterRepository(context: try makeContext(), calendar: calendar)
        let day = Date(timeIntervalSinceReferenceDate: 3_600)
        #expect(try water.add(500, at: day) == 500)
        #expect(try water.add(330, at: day) == 830)
        #expect(try water.remove(1_000, at: day) == 0)
        #expect(try water.remove(200, at: day) == 0)
        #expect(try water.add(200, at: day) == 200)
        #expect(try water.add(-50, at: day) == 200)

        let nextDay = day.addingTimeInterval(86_400)
        #expect(try water.total(on: nextDay) == 0)
    }
}
