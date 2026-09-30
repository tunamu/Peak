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

    public init(
        date: Date, waterMl: Int, waterGoalMl: Int, quickWaterMl: Int, steps: Int?, stepGoal: Int,
        energy: EnergyLevel?, workout: Workout
    ) {
        self.date = date
        self.waterMl = waterMl
        self.waterGoalMl = waterGoalMl
        self.quickWaterMl = quickWaterMl
        self.steps = steps
        self.stepGoal = stepGoal
        self.energy = energy
        self.workout = workout
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
            workout: workout(overview)
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
        energy: .ready, workout: .planned(name: "Back & Triceps", movements: 5, sets: 11))
}
