import Foundation
import PeakCore
import SwiftData
import Testing

/// F11-13: workouts entered after the fact.
@MainActor
@Suite struct ManualLogTests {
    private let calendar = DayPlannerTests.calendar

    private func day(_ text: String, _ hour: Int = 12) -> Date {
        DayPlannerTests.day(text, hour: hour)
    }

    /// A template with Bench Press, two sets.
    private func benchTemplate(in context: ModelContext) throws -> WorkoutTemplate {
        let templates = TemplateRepository(context: context)
        let template = try templates.create(name: "Chest")
        templates.setItems(
            [(try ExerciseRepository(context: context).findOrCreate(name: "Bench Press"), 2)], of: template)
        return template
    }

    /// A finished session of `template` at `date`, every set at `weightKg` × 10.
    @discardableResult
    private func finished(_ template: WorkoutTemplate, at date: Date, weightKg: Double, in context: ModelContext) throws
        -> WorkoutSession
    {
        let session = SessionRepository(context: context).start(from: template, at: date)
        let controller = WorkoutSessionController(session: session, context: context)
        for set in session.orderedExercises.flatMap(\.orderedSets) {
            try controller.setWeight(weightKg, of: set)
            try controller.setReps(10, of: set, at: date)
        }
        try controller.finish(at: date + 3_600)
        return session
    }

    @Test func targetsComeFromBeforeTheDay() throws {
        let context = try makeContext()
        let template = try benchTemplate(in: context)
        try finished(template, at: day("2026-09-21", 18), weightKg: 50, in: context)
        try finished(template, at: day("2026-09-25", 18), weightKg: 80, in: context)
        let sessions = SessionRepository(context: context)

        let past = sessions.startLog(from: template, start: day("2026-09-23", 18), duration: 3_600)
        let pastTarget = try #require(past.orderedExercises.first?.orderedSets.first?.targetWeightKg)
        #expect(pastTarget < 80)

        let live = sessions.start(from: template, at: day("2026-09-27", 18))
        #expect(try #require(live.orderedExercises.first?.orderedSets.first?.targetWeightKg) >= 80)
    }

    @Test func aWorkoutBeingEnteredIsNotRunningAndCanBeFoundAgain() throws {
        let context = try makeContext()
        let sessions = SessionRepository(context: context)
        let log = sessions.startLog(from: try benchTemplate(in: context), start: day("2026-09-23", 18), duration: 3_600)
        try context.save()

        #expect(log.status == .logging)
        #expect(try sessions.current() == nil)
        #expect(try sessions.completed().isEmpty)
        #expect(try sessions.openLog() == log)
    }

    @Test func savingCompletesItAtItsOwnTime() throws {
        let context = try makeContext()
        let start = day("2026-09-23", 18)
        let log = SessionRepository(context: context)
            .startLog(from: try benchTemplate(in: context), start: start, duration: 3_000)
        let controller = WorkoutSessionController(session: log, context: context)
        #expect(!controller.hasEntries)

        try controller.setLogTime(start: start + 600, duration: 2_400)
        let set = try #require(log.orderedExercises.first?.orderedSets.first)
        try controller.setWeight(60, of: set)
        try controller.setReps(8, of: set)
        #expect(controller.hasEntries)
        try controller.saveLog()

        #expect(log.status == .completed)
        #expect(log.startedAt == start + 600)
        #expect(log.endedAt == start + 3_000)
        #expect(log.duration() == 2_400)
        #expect(set.completedAt == start + 3_000)
        #expect(try SessionRepository(context: context).completed() == [log])
        #expect(try SessionRepository(context: context).openLog() == nil)
    }

    @Test func aWorkoutBeingEnteredNeitherRunsNorFinishes() throws {
        let context = try makeContext()
        let log = SessionRepository(context: context)
            .startLog(from: try benchTemplate(in: context), start: day("2026-09-23", 18), duration: 3_600)
        let controller = WorkoutSessionController(session: log, context: context)

        #expect(throws: WorkoutSessionController.TransitionError.notAllowed(from: .logging)) {
            try controller.pause()
        }
        #expect(throws: WorkoutSessionController.TransitionError.notAllowed(from: .logging)) {
            try controller.finish()
        }
        try controller.discard()
        #expect(try context.fetch(FetchDescriptor<WorkoutSession>()).isEmpty)
    }

    @Test func exportLeavesOutAWorkoutBeingEntered() throws {
        let context = try makeContext()
        let template = try benchTemplate(in: context)
        try finished(template, at: day("2026-09-21", 18), weightKg: 50, in: context)
        SessionRepository(context: context).startLog(from: template, start: day("2026-09-23", 18), duration: 3_600)
        try context.save()

        let export = try PeakExporter(context: context).export(settings: nil)
        #expect(export.sessions.count == 1)
        #expect(export.sessions.first?.status == .completed)
    }

    // MARK: Defaults

    @Test func defaultsToSixPMForAnHourWithoutHistory() {
        let plan = ManualLogPlan.defaults(
            on: day("2026-09-23", 9), now: day("2026-09-29"), previousStart: nil, previousDuration: nil,
            calendar: calendar)
        #expect(plan == ManualLogPlan(start: day("2026-09-23", 18), duration: 3_600))
    }

    @Test func defaultsToTheLastTimeOfDayAndLengthRounded() {
        let previousStart =
            calendar.date(
                from: DateComponents(year: 2026, month: 9, day: 20, hour: 7, minute: 30)) ?? .now
        let plan = ManualLogPlan.defaults(
            on: day("2026-09-23"), now: day("2026-09-29"), previousStart: previousStart, previousDuration: 47 * 60,
            calendar: calendar)
        let expected = calendar.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 7, minute: 30)) ?? .now
        #expect(plan == ManualLogPlan(start: expected, duration: 45 * 60))
    }

    @Test func todayEndsNowAndNeverBeforeMidnight() {
        let now = day("2026-09-29", 10)
        let plan = ManualLogPlan.defaults(
            on: now, now: now, previousStart: nil, previousDuration: nil, calendar: calendar)
        #expect(plan == ManualLogPlan(start: now - 3_600, duration: 3_600))
        #expect(plan.isValid(now: now))

        let justAfterMidnight = calendar.startOfDay(for: now) + 600
        let early = ManualLogPlan.defaults(
            on: justAfterMidnight, now: justAfterMidnight, previousStart: nil, previousDuration: nil,
            calendar: calendar)
        #expect(early == ManualLogPlan(start: calendar.startOfDay(for: now), duration: 600))
        #expect(!ManualLogPlan(start: now, duration: 60).isValid(now: now))
    }

    // MARK: Routines

    /// Entering the routine's missed Monday workout moves the rotation on, as doing it live would have.
    @Test func theRoutineWorkoutMovesTheRotationOn() throws {
        let context = try makeContext()
        try SampleProgram.install(into: context)
        let routine = try #require(try RoutineRepository(context: context).all().first)
        let planner = DayPlanner(calendar: calendar)
        let monday = day("2026-09-28")
        let all = { try context.fetch(FetchDescriptor<WorkoutSession>()) }

        let suggestion = try #require(
            planner.logSuggestions(on: monday, routines: [routine], sessions: try all()).first)
        #expect(suggestion.template.name == "Chest & Biceps")

        let log = SessionRepository(context: context).startLog(
            from: suggestion.template, routine: suggestion.routine, start: day("2026-09-28", 18), duration: 3_600)
        try WorkoutSessionController(session: log, context: context).saveLog()

        #expect(planner.logSuggestions(on: monday, routines: [routine], sessions: try all()).isEmpty)
        let wednesday = planner.overview(
            of: day("2026-09-30"), today: DayPlannerTests.today, routines: [routine], sessions: try all())
        #expect(wednesday.workouts.map { $0.isPlanned } == [true])
        if case .planned(let template, _)? = wednesday.workouts.first {
            #expect(template.name == "Back & Triceps")
        }
        let past = planner.overview(of: monday, today: DayPlannerTests.today, routines: [routine], sessions: try all())
        #expect(past.workouts.count == 1)
    }
}
