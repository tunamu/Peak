import Foundation

/// One workout card on the Home screen (C-03).
public enum DayWorkout: Hashable {
    /// Planned by a routine and not started yet.
    case planned(WorkoutTemplate, routine: Routine?)
    /// Running or paused (only on today).
    case active(WorkoutSession)
    /// Done on that day.
    case completed(WorkoutSession)
}

extension DayWorkout {
    /// Planned and not started.
    public var isPlanned: Bool {
        if case .planned = self { return true }
        return false
    }
}

/// A routine's workout offered first when entering a workout for a day after the fact (F11-13).
public struct LogSuggestion {
    public var template: WorkoutTemplate
    public var routine: Routine
}

/// Everything the Home screen shows about one day's workouts.
public struct DayOverview {
    /// Completed first, then the running session, then planned ones in routine order.
    public var workouts: [DayWorkout]
    /// When the day has no workout: the next day with a planned one (looking four weeks ahead). Only for today and
    /// later.
    public var nextWorkoutDay: Date?
    /// Whether any routine is active; without one, Home offers to set one up.
    public var hasActiveRoutine: Bool

    /// The workout the main Start button (and the bottom accessory) targets: the first not yet done.
    public var firstPending: DayWorkout? {
        workouts.first {
            if case .completed = $0 { return false }
            return true
        }
    }
}

/// Turns stored routines and sessions into what Home shows for a day: the SwiftData side of `RoutineScheduler`.
@MainActor
public struct DayPlanner {
    public var calendar: Calendar
    /// How far ahead a rest day looks for the next workout.
    public static let lookaheadDays = 28

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// - Parameters:
    ///   - sessions: Sessions of any status; discarded ones are ignored.
    public func overview(
        of day: Date,
        today: Date,
        routines: [Routine],
        sessions: [WorkoutSession]
    ) -> DayOverview {
        let start = calendar.startOfDay(for: day)
        let startOfToday = calendar.startOfDay(for: today)
        let completed = sessions.filter { $0.status == .completed }
        let hasActiveRoutine = routines.contains { $0.isActive && !$0.orderedEntries.isEmpty }

        var workouts: [DayWorkout] =
            completed
            .filter { calendar.isDate($0.startedAt, inSameDayAs: start) }
            .sorted { $0.startedAt < $1.startedAt }
            .map { .completed($0) }

        guard start >= startOfToday else {
            return DayOverview(workouts: workouts, nextWorkoutDay: nil, hasActiveRoutine: hasActiveRoutine)
        }

        let running = sessions.filter { $0.status == .active || $0.status == .paused }
        if start == startOfToday {
            workouts += running.sorted { $0.startedAt < $1.startedAt }.map { .active($0) }
        }

        let days = (0...Self.lookaheadDays).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        let plan = RoutineScheduler(calendar: calendar).plan(
            routines: routines.map(\.snapshot),
            history: completed.map(\.record),
            days: days,
            today: startOfToday
        )
        let routinesByID = Dictionary(routines.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let templatesByID = Dictionary(
            routines.flatMap(\.orderedEntries).compactMap(\.template).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        for entry in plan[start] ?? [] where entry.status == .planned {
            guard let templateID = entry.templateID, let template = templatesByID[templateID] else { continue }
            // A running session already stands for this routine's workout today.
            let isRunning =
                start == startOfToday
                && running.contains {
                    entry.routineID != nil ? $0.routine?.id == entry.routineID : $0.template?.id == templateID
                }
            if !isRunning {
                workouts.append(.planned(template, routine: entry.routineID.flatMap { routinesByID[$0] }))
            }
        }

        var next: Date?
        if workouts.isEmpty {
            next = days.dropFirst().first { plan[$0]?.contains { $0.status == .planned } == true }
        }
        return DayOverview(workouts: workouts, nextWorkoutDay: next, hasActiveRoutine: hasActiveRoutine)
    }

    /// The days among `days` with a completed or planned workout, as start of day; for the week strip's labels.
    public func workoutDays(
        in days: [Date],
        today: Date,
        routines: [Routine],
        sessions: [WorkoutSession]
    ) -> Set<Date> {
        let completed = sessions.filter { $0.status == .completed }
        let plan = RoutineScheduler(calendar: calendar).plan(
            routines: routines.map(\.snapshot),
            history: completed.map(\.record),
            days: days,
            today: today
        )
        return Set(plan.filter { !$0.value.isEmpty }.keys)
    }

    /// What each active routine had next on `day`, for entering a workout after the fact (F11-13): the rotation as it
    /// stood before that day. A routine already done that day suggests nothing. In routine order.
    public func logSuggestions(on day: Date, routines: [Routine], sessions: [WorkoutSession]) -> [LogSuggestion] {
        let dayStart = calendar.startOfDay(for: day)
        let completed = sessions.filter { $0.status == .completed }
        let before = completed.filter { $0.startedAt < dayStart }.map(\.record)
        let scheduler = RoutineScheduler(calendar: calendar)
        return routines.filter { $0.isActive }.sorted { $0.sortIndex < $1.sortIndex }.compactMap { routine in
            let isDone = completed.contains {
                $0.routine?.id == routine.id && calendar.isDate($0.startedAt, inSameDayAs: dayStart)
            }
            guard !isDone, let templateID = scheduler.nextTemplate(for: routine.snapshot, history: before),
                let template = routine.orderedEntries.compactMap(\.template).first(where: { $0.id == templateID })
            else { return nil }
            return LogSuggestion(template: template, routine: routine)
        }
    }

    /// The workout half of the energy score at `now`: strength sessions of the past week, and the muscles of the
    /// workout planned next.
    public func energyInput(now: Date, sessions: [WorkoutSession], planned: WorkoutTemplate?) -> EnergyInput {
        let weekAgo = now.addingTimeInterval(-7 * 86_400)
        let workouts = sessions.compactMap { session -> EnergyInput.Workout? in
            guard session.status == .completed, let end = session.endedAt, end >= weekAgo else { return nil }
            let muscles = Set(
                session.orderedExercises.compactMap(\.exercise).filter { $0.kind == .strength }.map(\.muscleGroup)
            )
            // A walk alone is not a strength workout.
            return muscles.isEmpty ? nil : EnergyInput.Workout(endedAt: end, muscleGroups: muscles)
        }
        let plannedMuscles = Set(
            (planned?.orderedItems ?? []).compactMap(\.exercise).filter { $0.kind == .strength }.map(\.muscleGroup)
        )
        return EnergyInput(now: now, workouts: workouts, plannedMuscleGroups: plannedMuscles)
    }
}

extension Routine {
    /// The routine as `RoutineScheduler` sees it. Entries whose template is gone are left out.
    public var snapshot: RoutineSnapshot {
        let schedule: RoutineSnapshot.Schedule =
            switch scheduleType {
            case .weekdays: .weekdays(Set(weekdays))
            case .interval: .interval(days: intervalDays, start: startDate)
            }
        return RoutineSnapshot(
            id: id,
            sortIndex: sortIndex,
            isActive: isActive,
            schedule: schedule,
            entries: orderedEntries.compactMap { entry in
                entry.template.map { .init(templateID: $0.id, isArchived: $0.isArchived) }
            }
        )
    }
}

extension WorkoutSession {
    public var record: WorkoutRecord {
        WorkoutRecord(routineID: routine?.id, templateID: template?.id, date: startedAt)
    }

    /// Movements marked done, or whose every set has reps: the "5" of "42 min · 5/5".
    public var completedMovementCount: Int {
        orderedExercises.filter { exercise in
            exercise.isCompleted || (!(exercise.sets ?? []).isEmpty && (exercise.sets ?? []).allSatisfy { $0.reps > 0 })
        }.count
    }
}

extension WorkoutTemplate {
    /// Movements in the template ("5 Movements").
    public var movementCount: Int {
        orderedItems.count { $0.exercise != nil }
    }

    /// Strength sets in the template ("13 Sets"); a cardio movement has none.
    public var setCount: Int {
        orderedItems.filter { $0.exercise?.kind == .strength }.reduce(0) { $0 + $1.targetSets }
    }
}
