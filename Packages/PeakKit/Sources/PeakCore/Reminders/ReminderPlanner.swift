import Foundation

/// A local notification to schedule (F11-07, ADR 0021).
public struct PlannedReminder: Hashable, Sendable, Identifiable {
    public enum Kind: Hashable, Sendable {
        /// "Today: Chest & Biceps. Ready?" on a workout day.
        case morning
        /// The routine's own "time to train" reminder.
        case routine(UUID)
    }

    /// Stable for the same day and kind, so scheduling again replaces it: `peak.reminder.morning.2026-10-02`.
    public var id: String
    public var kind: Kind
    public var date: Date
    /// The workouts planned for that day (morning) or that routine's workout (routine), in routine order.
    public var workoutNames: [String]

    public init(id: String, kind: Kind, date: Date, workoutNames: [String]) {
        self.id = id
        self.kind = kind
        self.date = date
        self.workoutNames = workoutNames
    }
}

/// What the planner needs, as plain values (docs/NOTIFICATIONS.md).
public struct ReminderInput: Sendable {
    public var routines: [RoutineSnapshot]
    /// Completed sessions, for the rotation.
    public var history: [WorkoutRecord]
    public var templateNames: [UUID: String]
    /// The morning reminder's time in minutes after midnight; `nil` when it is off.
    public var morningMinutes: Int?
    /// Each routine's own reminder time in minutes after midnight, for routines that have one on.
    public var routineMinutes: [UUID: Int]
    /// A workout is running: today gets no reminder.
    public var hasRunningSession: Bool

    public init(
        routines: [RoutineSnapshot],
        history: [WorkoutRecord],
        templateNames: [UUID: String],
        morningMinutes: Int?,
        routineMinutes: [UUID: Int] = [:],
        hasRunningSession: Bool = false
    ) {
        self.routines = routines
        self.history = history
        self.templateNames = templateNames
        self.morningMinutes = morningMinutes
        self.routineMinutes = routineMinutes
        self.hasRunningSession = hasRunningSession
    }
}

/// Which reminders fall when, from the routines' plan (D-28). Pure, so it is tested without the notification center.
///
/// Reminders are planned `days` ahead and planned again whenever the app opens or the data changes: the rotation
/// moves with what was done, so a later day's workout can change. A day whose planned workouts are all done (the
/// scheduler then plans nothing for it), or today while a workout is running, gets none.
public struct ReminderPlanner: Sendable {
    /// How far ahead reminders are scheduled. iOS keeps at most 64 pending; two a day for 14 days stays under it.
    public static let days = 14
    public static let limit = 60

    public var calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func plan(_ input: ReminderInput, now: Date) -> [PlannedReminder] {
        let today = calendar.startOfDay(for: now)
        let days = (0..<Self.days).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
        let plan = RoutineScheduler(calendar: calendar).plan(
            routines: input.routines, history: input.history, days: days, today: today)
        var reminders: [PlannedReminder] = []
        for day in days {
            if day == today && input.hasRunningSession { continue }
            let planned = (plan[day] ?? []).filter { $0.status == .planned }
            guard !planned.isEmpty else { continue }
            let key = Self.dayKey(day, calendar: calendar)

            if let minutes = input.morningMinutes, let date = time(minutes, on: day), date > now {
                var names: [String] = []
                for name in planned.compactMap({ $0.templateID.flatMap { input.templateNames[$0] } })
                where !names.contains(name) {
                    names.append(name)
                }
                reminders.append(
                    PlannedReminder(id: "peak.reminder.morning.\(key)", kind: .morning, date: date, workoutNames: names)
                )
            }
            for workout in planned {
                guard let routineID = workout.routineID, let minutes = input.routineMinutes[routineID],
                    let date = time(minutes, on: day), date > now
                else { continue }
                reminders.append(
                    PlannedReminder(
                        id: "peak.reminder.routine.\(routineID.uuidString).\(key)", kind: .routine(routineID),
                        date: date,
                        workoutNames: workout.templateID.flatMap { input.templateNames[$0] }.map { [$0] } ?? []
                    ))
            }
        }
        return Array(reminders.sorted { $0.date < $1.date }.prefix(Self.limit))
    }

    private func time(_ minutes: Int, on day: Date) -> Date? {
        let clamped = min(max(minutes, 0), 24 * 60 - 1)
        return calendar.date(bySettingHour: clamped / 60, minute: clamped % 60, second: 0, of: day)
    }

    /// "2026-10-02".
    static func dayKey(_ day: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
