import Foundation
import SwiftData

/// What the app knows from Apple Health for today, left in the App Group for the widgets (C-16). Health data never
/// goes into the store (App Review 5.1.3); this small file is a cache the app rewrites whenever Home loads Health.
public struct WidgetSnapshot: Codable, Equatable, Sendable {
    /// The day the values are for; on another day the widgets show no steps or energy.
    public var day: LocalDate
    public var steps: Int?
    public var energy: EnergyLevel?

    public init(day: LocalDate, steps: Int?, energy: EnergyLevel?) {
        self.day = day
        self.steps = steps
        self.energy = energy
    }

    public static let fileName = "widget-snapshot.json"

    /// The App Group file, or `nil` when the group is missing (an unsigned build).
    public static var url: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: PeakStore.appGroupID)?
            .appending(path: fileName)
    }

    public static func read(from url: URL? = url) -> WidgetSnapshot? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    public func write(to url: URL? = Self.url) throws {
        guard let url else { return }
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
    }
}

/// Everything the widgets show at one moment: today's water from the store, today's workout from the routines, and
/// steps and energy from the snapshot. Built the same way in the widget and in tests.
public struct WidgetContent: Equatable, Sendable {
    public enum Workout: Equatable, Sendable {
        /// Planned by a routine and not started.
        case planned(name: String, movements: Int, sets: Int)
        /// Running or paused.
        case active(name: String, startedAt: Date, isPaused: Bool)
        case completed(name: String, duration: TimeInterval)
        /// A rest day, with the next workout's day when there is one.
        case rest(next: Date?)
        /// No active routine.
        case none
    }

    public var date: Date
    public var waterMl: Int
    public var waterGoalMl: Int
    /// The water sheet's first amount: what the widget's button adds.
    public var quickWaterMl: Int
    public var steps: Int?
    public var stepGoal: Int
    public var energy: EnergyLevel?
    public var workout: Workout
    /// This week at a glance, for the large widget (F11-11).
    public var week: WeekGlance
    /// kg or lb, for the week's volume.
    public var unitSystem: UnitSystem

    public init(
        date: Date, waterMl: Int, waterGoalMl: Int, quickWaterMl: Int, steps: Int?, stepGoal: Int,
        energy: EnergyLevel?, workout: Workout, week: WeekGlance = .empty, unitSystem: UnitSystem = .metric
    ) {
        self.date = date
        self.waterMl = waterMl
        self.waterGoalMl = waterGoalMl
        self.quickWaterMl = quickWaterMl
        self.steps = steps
        self.stepGoal = stepGoal
        self.energy = energy
        self.workout = workout
        self.week = week
        self.unitSystem = unitSystem
    }

    /// Today's content from the shared store, the settings and the snapshot.
    @MainActor
    public static func make(
        context: ModelContext, settings: SettingsStore, snapshot: WidgetSnapshot?, now: Date = .now,
        calendar: Calendar = .current
    ) throws -> WidgetContent {
        let routines = try context.fetch(FetchDescriptor<Routine>())
        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        let overview = DayPlanner(calendar: calendar).overview(
            of: now, today: now, routines: routines, sessions: sessions)
        let isToday = snapshot?.day == LocalDate(now, calendar: calendar)
        return WidgetContent(
            date: now,
            waterMl: try WaterRepository(context: context, calendar: calendar).total(on: now),
            waterGoalMl: settings.waterGoalMl,
            quickWaterMl: settings.quickWaterAmounts.first ?? 200,
            steps: isToday ? snapshot?.steps : nil,
            stepGoal: settings.stepGoal,
            energy: isToday ? snapshot?.energy : nil,
            workout: workout(overview),
            week: WeekGlance.make(routines: routines, sessions: sessions, now: now, calendar: calendar),
            unitSystem: settings.unitSystem
        )
    }

    /// The first workout still to do today, else the last one done, else a rest day.
    private static func workout(_ overview: DayOverview) -> Workout {
        switch overview.firstPending ?? overview.workouts.last {
        case .planned(let template, _)?:
            return .planned(name: template.name, movements: template.movementCount, sets: template.setCount)
        case .active(let session)?:
            return .active(
                name: session.title, startedAt: session.startedAt.addingTimeInterval(session.pausedTotal),
                isPaused: session.status == .paused)
        case .completed(let session)?:
            return .completed(name: session.title, duration: session.duration())
        case nil:
            return overview.hasActiveRoutine ? .rest(next: overview.nextWorkoutDay) : .none
        }
    }

    /// A sample for the widget gallery and placeholders.
    public static let sample = WidgetContent(
        date: .now, waterMl: 1_800, waterGoalMl: 4_000, quickWaterMl: 200, steps: 7_598, stepGoal: 10_000,
        energy: .ready, workout: .planned(name: "Back & Triceps", movements: 5, sets: 11), week: .sample)
}

/// A day on the large widget's week.
public enum WeekDayStatus: Equatable, Sendable {
    case done, planned, none
}

/// The week containing today, for the large widget: which days had or have a workout, and the week's totals.
public struct WeekGlance: Equatable, Sendable {
    public struct Day: Equatable, Sendable {
        public var date: Date
        public var status: WeekDayStatus

        public init(date: Date, status: WeekDayStatus) {
            self.date = date
            self.status = status
        }
    }

    /// The calendar's week, starting on the locale's first weekday.
    public var days: [Day]
    /// Completed this week.
    public var workouts: Int
    public var volumeKg: Double
    /// Weeks in a row with a workout (`PerformanceAnalysis.streakWeeks`).
    public var streakWeeks: Int

    public init(days: [Day], workouts: Int, volumeKg: Double, streakWeeks: Int) {
        self.days = days
        self.workouts = workouts
        self.volumeKg = volumeKg
        self.streakWeeks = streakWeeks
    }

    public static let empty = WeekGlance(days: [], workouts: 0, volumeKg: 0, streakWeeks: 0)

    /// Done on Monday and Wednesday, planned on Friday.
    public static let sample: WeekGlance = {
        let calendar = Calendar.current
        let days = RoutineScheduler(calendar: calendar).week(containing: .now)
        let statuses: [WeekDayStatus] = [.done, .none, .done, .none, .planned, .none, .none]
        return WeekGlance(
            days: zip(days, statuses).map { Day(date: $0, status: $1) }, workouts: 2, volumeKg: 8_420,
            streakWeeks: 6)
    }()

    /// - Parameters:
    ///   - sessions: Sessions of any status; only completed ones count.
    @MainActor
    public static func make(routines: [Routine], sessions: [WorkoutSession], now: Date, calendar: Calendar)
        -> WeekGlance
    {
        let days = RoutineScheduler(calendar: calendar).week(containing: now)
        let completed = sessions.filter { $0.status == .completed }
        let doneDays = Set(completed.map { calendar.startOfDay(for: $0.startedAt) })
        let workoutDays = DayPlanner(calendar: calendar).workoutDays(
            in: days, today: now, routines: routines, sessions: sessions)
        let today = calendar.startOfDay(for: now)
        let week = days.first.map { $0..<(calendar.date(byAdding: .day, value: 7, to: $0) ?? $0) }
        let thisWeek = completed.filter { week?.contains($0.startedAt) ?? false }.map(\.analysisSession)
        return WeekGlance(
            days: days.map { day in
                let start = calendar.startOfDay(for: day)
                let status: WeekDayStatus =
                    doneDays.contains(start)
                    ? .done : (start >= today && workoutDays.contains(start) ? .planned : .none)
                return Day(date: start, status: status)
            },
            workouts: thisWeek.count,
            volumeKg: thisWeek.reduce(0) { $0 + $1.volumeKg },
            streakWeeks: PerformanceAnalysis.streakWeeks(
                of: completed.map(\.analysisSession), now: now, calendar: calendar)
        )
    }
}
