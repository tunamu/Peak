import Foundation

/// A routine as the scheduler sees it.
public struct RoutineSnapshot: Hashable, Sendable {
    public enum Schedule: Hashable, Sendable {
        /// Fixed weekdays ("Every Week Day").
        case weekdays(Set<Weekday>)
        /// Every `days` days after the last workout; `start` is the first workout day.
        case interval(days: Int, start: Date)
    }

    public struct Entry: Hashable, Sendable {
        public var templateID: UUID
        public var isArchived: Bool

        public init(templateID: UUID, isArchived: Bool = false) {
            self.templateID = templateID
            self.isArchived = isArchived
        }
    }

    public var id: UUID
    public var sortIndex: Int
    public var isActive: Bool
    public var schedule: Schedule
    /// The rotation, in order.
    public var entries: [Entry]

    public init(id: UUID = UUID(), sortIndex: Int = 0, isActive: Bool = true, schedule: Schedule, entries: [Entry]) {
        self.id = id
        self.sortIndex = sortIndex
        self.isActive = isActive
        self.schedule = schedule
        self.entries = entries
    }
}

/// A completed session.
public struct WorkoutRecord: Hashable, Sendable {
    public var routineID: UUID?
    public var templateID: UUID?
    public var date: Date

    public init(routineID: UUID?, templateID: UUID?, date: Date) {
        self.routineID = routineID
        self.templateID = templateID
        self.date = date
    }
}

/// One workout on one day: done, or planned by a routine.
public struct PlannedWorkout: Hashable, Sendable {
    public enum Status: Hashable, Sendable {
        case completed
        case planned
    }

    public var day: Date
    public var routineID: UUID?
    public var templateID: UUID?
    public var status: Status
}

/// Which workout falls on which day (docs/ROUTINES.md).
///
/// The rotation cursor is never stored: the next template is the one after the routine's last completed session.
/// A missed day does not skip a workout; the workout moves to the next scheduled day.
public struct RoutineScheduler: Sendable {
    public var calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// The template the routine would do next, skipping archived entries. `nil` when nothing is left to do.
    public func nextTemplate(for routine: RoutineSnapshot, history: [WorkoutRecord]) -> UUID? {
        let last =
            history
            .filter { $0.routineID == routine.id && $0.templateID != nil }
            .max { $0.date < $1.date }
        let lastIndex = last.flatMap { record in routine.entries.firstIndex { $0.templateID == record.templateID } }
        return template(after: lastIndex, in: routine)
    }

    /// Completed and planned workouts for each of `days`, as the week strip shows them.
    ///
    /// Days before `today` show only what was done. From `today` on, each active routine's scheduled days take the
    /// next templates in turn; a routine already done today is not planned again today. Workouts on the same day are
    /// ordered by routine `sortIndex`.
    public func plan(
        routines: [RoutineSnapshot],
        history: [WorkoutRecord],
        days: [Date],
        today: Date
    ) -> [Date: [PlannedWorkout]] {
        let startOfToday = calendar.startOfDay(for: today)
        let sortedDays = days.map { calendar.startOfDay(for: $0) }.sorted()
        let order = Dictionary(routines.map { ($0.id, $0.sortIndex) }, uniquingKeysWith: { first, _ in first })
        var result: [Date: [PlannedWorkout]] = [:]

        for record in history {
            let day = calendar.startOfDay(for: record.date)
            guard sortedDays.contains(day), day <= startOfToday else { continue }
            result[day, default: []].append(
                PlannedWorkout(day: day, routineID: record.routineID, templateID: record.templateID, status: .completed)
            )
        }

        for routine in routines where routine.isActive {
            let planned = projection(of: routine, history: history, from: startOfToday, through: sortedDays)
            for (day, templateID) in planned {
                result[day, default: []].append(
                    PlannedWorkout(day: day, routineID: routine.id, templateID: templateID, status: .planned)
                )
            }
        }

        for day in result.keys {
            result[day]?.sort {
                ($0.status == .completed ? 0 : 1, order[$0.routineID ?? UUID()] ?? .max)
                    < ($1.status == .completed ? 0 : 1, order[$1.routineID ?? UUID()] ?? .max)
            }
        }
        return result
    }

    /// The seven days of the week containing `date`, starting on the calendar's first weekday (V-06).
    public func week(containing date: Date) -> [Date] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }

    // MARK: Private

    /// Planned (day, template) pairs from `today` to the last of `days`.
    private func projection(
        of routine: RoutineSnapshot,
        history: [WorkoutRecord],
        from today: Date,
        through days: [Date]
    ) -> [(Date, UUID)] {
        guard let lastDay = days.last, lastDay >= today else { return [] }
        let own = history.filter { $0.routineID == routine.id }
        let doneToday = own.contains { calendar.isDate($0.date, inSameDayAs: today) }
        var cursor = own.filter { $0.templateID != nil }.max { $0.date < $1.date }.flatMap { record in
            routine.entries.firstIndex { $0.templateID == record.templateID }
        }
        var lastWorkout = own.map { calendar.startOfDay(for: $0.date) }.max()
        var result: [(Date, UUID)] = []
        var day = doneToday ? addingDays(1, to: today) : today

        while day <= lastDay {
            if isScheduled(day, routine: routine, lastWorkout: lastWorkout),
                let index = nextIndex(after: cursor, in: routine)
            {
                if days.contains(day) {
                    result.append((day, routine.entries[index].templateID))
                }
                cursor = index
                lastWorkout = day
            }
            day = addingDays(1, to: day)
        }
        return result
    }

    private func isScheduled(_ day: Date, routine: RoutineSnapshot, lastWorkout: Date?) -> Bool {
        switch routine.schedule {
        case .weekdays(let weekdays):
            return weekdays.contains(Weekday(of: day, calendar: calendar))
        case .interval(let interval, let start):
            let due = lastWorkout.map { addingDays(max(1, interval), to: $0) } ?? calendar.startOfDay(for: start)
            return day >= due
        }
    }

    private func template(after index: Int?, in routine: RoutineSnapshot) -> UUID? {
        nextIndex(after: index, in: routine).map { routine.entries[$0].templateID }
    }

    /// The next non-archived entry after `index` (from the start when `nil`), wrapping around.
    private func nextIndex(after index: Int?, in routine: RoutineSnapshot) -> Int? {
        let count = routine.entries.count
        guard count > 0 else { return nil }
        let start = index.map { $0 + 1 } ?? 0
        return (0..<count).lazy.map { (start + $0) % count }.first { !routine.entries[$0].isArchived }
    }

    private func addingDays(_ value: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: value, to: date) ?? date.addingTimeInterval(Double(value) * 86_400)
    }
}
