import Foundation
import PeakCore
import SwiftData
import Testing

@MainActor
@Suite struct DayPlannerTests {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        calendar.firstWeekday = 2  // Monday
        return calendar
    }()

    static let planner = DayPlanner(calendar: calendar)

    static func day(_ text: String, hour: Int = 12) -> Date {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: hour)) ?? .now
    }

    /// The sample program (six templates, Monday/Wednesday/Friday) in a fresh store.
    func sampleStore() throws -> (ModelContext, Routine) {
        let context = try makeContext()
        try SampleProgram.install(into: context)
        let routine = try #require(try RoutineRepository(context: context).all().first)
        return (context, routine)
    }

    func sessions(_ context: ModelContext) throws -> [WorkoutSession] {
        try context.fetch(FetchDescriptor<WorkoutSession>())
    }

    func names(_ workouts: [DayWorkout]) -> [String] {
        workouts.map {
            switch $0 {
            case .planned(let template, _): "planned \(template.name)"
            case .active(let session): "active \(session.title)"
            case .completed(let session): "completed \(session.title)"
            }
        }
    }

    // Tuesday 29.09.2026 is today in these tests.
    static let today = day("2026-09-29")

    @Test func plansTheRotationOnScheduledDays() throws {
        let (context, routine) = try sampleStore()
        let wednesday = Self.planner.overview(
            of: Self.day("2026-09-30"), today: Self.today, routines: [routine], sessions: try sessions(context))
        #expect(names(wednesday.workouts) == ["planned Chest & Biceps"])

        let friday = Self.planner.overview(
            of: Self.day("2026-10-02"), today: Self.today, routines: [routine], sessions: try sessions(context))
        #expect(names(friday.workouts) == ["planned Back & Triceps"])
    }

    @Test func restDayPointsAtTheNextWorkout() throws {
        let (context, routine) = try sampleStore()
        let tuesday = Self.planner.overview(
            of: Self.today, today: Self.today, routines: [routine], sessions: try sessions(context))
        #expect(tuesday.workouts.isEmpty)
        #expect(tuesday.nextWorkoutDay == Self.calendar.startOfDay(for: Self.day("2026-09-30")))
        #expect(tuesday.hasActiveRoutine)
    }

    @Test func pastDaysShowOnlyWhatWasDone() throws {
        let (context, routine) = try sampleStore()
        try SampleProgram.installHistory(into: context, now: Self.today, calendar: Self.calendar)

        // Monday 28.09 was the third seeded session (after 23.09 and 25.09).
        let monday = Self.planner.overview(
            of: Self.day("2026-09-28"), today: Self.today, routines: [routine], sessions: try sessions(context))
        #expect(names(monday.workouts) == ["completed Shoulder & Biceps"])
        #expect(monday.nextWorkoutDay == nil)

        let sunday = Self.planner.overview(
            of: Self.day("2026-09-27"), today: Self.today, routines: [routine], sessions: try sessions(context))
        #expect(sunday.workouts.isEmpty)

        // The rotation continues after the history.
        let wednesday = Self.planner.overview(
            of: Self.day("2026-09-30"), today: Self.today, routines: [routine], sessions: try sessions(context))
        #expect(names(wednesday.workouts) == ["planned Chest & Triceps"])
    }

    @Test func runningSessionReplacesItsPlannedWorkout() throws {
        let (context, routine) = try sampleStore()
        let wednesday = Self.day("2026-09-30")
        let template = try #require(routine.orderedEntries.first?.template)
        SessionRepository(context: context).start(from: template, routine: routine, at: wednesday)

        let overview = Self.planner.overview(
            of: wednesday, today: wednesday, routines: [routine], sessions: try sessions(context))
        #expect(names(overview.workouts) == ["active Chest & Biceps"])
        if case .active = overview.firstPending {} else { Issue.record("The running session should be first") }
    }

    @Test func completedTodayIsNotPlannedAgain() throws {
        let (context, routine) = try sampleStore()
        let wednesday = Self.day("2026-09-30")
        let repository = SessionRepository(context: context)
        let template = try #require(routine.orderedEntries.first?.template)
        repository.complete(repository.start(from: template, routine: routine, at: wednesday))

        let overview = Self.planner.overview(
            of: wednesday, today: wednesday, routines: [routine], sessions: try sessions(context))
        #expect(names(overview.workouts) == ["completed Chest & Biceps"])
        #expect(overview.firstPending == nil)
    }

    @Test func twoRoutinesOnOneDayStackInRoutineOrder() throws {
        let (context, routine) = try sampleStore()
        try SampleProgram.installSecondRoutine(into: context, now: Self.today)
        let routines = try RoutineRepository(context: context).all()
        #expect(routines.count == 2)

        let wednesday = Self.day("2026-09-30")
        let overview = Self.planner.overview(
            of: wednesday, today: wednesday, routines: routines, sessions: try sessions(context))
        #expect(names(overview.workouts) == ["planned Chest & Biceps", "planned Back & Biceps"])

        // Starting the first leaves the second planned: only its Start waits.
        let template = try #require(routine.orderedEntries.first?.template)
        SessionRepository(context: context).start(from: template, routine: routine, at: wednesday)
        let running = Self.planner.overview(
            of: wednesday, today: wednesday, routines: routines, sessions: try sessions(context))
        #expect(names(running.workouts) == ["active Chest & Biceps", "planned Back & Biceps"])
        #expect(running.workouts.map(\.isPlanned) == [false, true])
    }

    @Test func withoutRoutinesThereIsNothingToPlan() throws {
        let context = try makeContext()
        let overview = Self.planner.overview(of: Self.today, today: Self.today, routines: [], sessions: [])
        #expect(overview.workouts.isEmpty)
        #expect(!overview.hasActiveRoutine)
        #expect(overview.nextWorkoutDay == nil)
        _ = context
    }

    @Test func weekLabelsMarkDoneAndPlannedDays() throws {
        let (context, routine) = try sampleStore()
        try SampleProgram.installHistory(into: context, now: Self.today, calendar: Self.calendar)
        let week = RoutineScheduler(calendar: Self.calendar).week(containing: Self.today)
        let days = Self.planner.workoutDays(
            in: week, today: Self.today, routines: [routine], sessions: try sessions(context))
        let expected = ["2026-09-28", "2026-09-30", "2026-10-02"].map { Self.calendar.startOfDay(for: Self.day($0)) }
        #expect(days == Set(expected))
    }

    @Test func energyInputUsesStrengthSessionsAndThePlannedMuscles() throws {
        let (context, routine) = try sampleStore()
        try SampleProgram.installHistory(into: context, now: Self.today, calendar: Self.calendar)
        let planned = try #require(routine.orderedEntries[3].template)  // Chest & Triceps
        let input = Self.planner.energyInput(now: Self.today, sessions: try sessions(context), planned: planned)
        #expect(input.workouts.count == 3)
        #expect(input.plannedMuscleGroups == [.chest, .triceps])

        // Monday's Shoulder & Biceps was 17.5 hours earlier.
        let result = EnergyEngine(calendar: Self.calendar).evaluate(input)
        #expect(result.reasons.map(\.points) == [EnergyConfig.recentWorkoutPenalty])
        #expect(result.level == .ready)
    }

    @Test func templateCounts() throws {
        let (_, routine) = try sampleStore()
        let backAndTriceps = try #require(routine.orderedEntries[1].template)
        #expect(backAndTriceps.movementCount == 5)
        #expect(backAndTriceps.setCount == 11)  // Row has three sets
    }

    @Test func historySeedIsIdempotent() throws {
        let (context, _) = try sampleStore()
        try SampleProgram.installHistory(into: context, now: Self.today, calendar: Self.calendar)
        try SampleProgram.installHistory(into: context, now: Self.today, calendar: Self.calendar)
        let all = try sessions(context)
        #expect(all.count == 3)
        #expect(all.allSatisfy { $0.completedMovementCount == $0.orderedExercises.count })
    }
}

@MainActor
@Suite struct HealthConnectionTests {
    @Test func connectingStartsFromUndetermined() async {
        let mock = MockHealthService(status: .notDetermined)
        let connection = HealthConnection(service: mock)
        await connection.refresh()
        #expect(connection.status == .notDetermined)
        await connection.requestAccess()
        #expect(connection.status == .connected)
        #expect(connection.revision == 1)
    }

    @Test func energySignalsFeedTheScore() {
        let input = EnergyInput(now: .now).with(EnergySignals(sleepDuration: 4 * 3_600))
        let result = EnergyEngine().evaluate(input)
        #expect(result.sources.contains(.sleep))
        #expect(result.score == 100 - EnergyConfig.shortSleepPenalty)
    }
}
