import Foundation
import PeakCore
import Testing

/// F11-07: which reminders fall when (docs/NOTIFICATIONS.md). Uses the sample rotation of `RoutineSchedulerTests`.
@Suite struct ReminderPlannerTests {
    typealias Schedule = RoutineSchedulerTests

    static let planner = ReminderPlanner(calendar: Schedule.calendar)
    static let names = Dictionary(uniqueKeysWithValues: zip(Schedule.templateIDs, Schedule.names))

    static func at(_ day: String, _ hour: Int, _ minute: Int = 0) -> Date {
        let start = Schedule.calendar.startOfDay(for: Schedule.day(day))
        return Schedule.calendar.date(bySettingHour: hour, minute: minute, second: 0, of: start) ?? start
    }

    static func input(
        _ routine: RoutineSnapshot,
        morning: Int? = 9 * 60,
        routineMinutes: [UUID: Int] = [:],
        running: Bool = false
    ) -> ReminderInput {
        ReminderInput(
            routines: [routine], history: Schedule.history(for: routine), templateNames: names,
            morningMinutes: morning, routineMinutes: routineMinutes, hasRunningSession: running)
    }

    /// Monday, Wednesday and Friday after the real log's 28.09: a 09:00 reminder naming the day's workout.
    @Test func morningRemindersOnWorkoutDays() {
        let routine = Schedule.mainRoutine()
        let reminders = Self.planner.plan(Self.input(routine), now: Self.at("2026-09-29", 8))
        let first = reminders.prefix(3)
        #expect(first.map(\.date) == [Self.at("2026-09-30", 9), Self.at("2026-10-02", 9), Self.at("2026-10-05", 9)])
        #expect(first.map(\.workoutNames) == [["Back & Triceps"], ["Shoulder & Biceps"], ["Chest & Triceps"]])
        #expect(first.first?.id == "peak.reminder.morning.2026-09-30")
        #expect(reminders.allSatisfy { $0.kind == .morning })
        // 14 days ahead from Tuesday 29.09: six workout days.
        #expect(reminders.count == 6)
    }

    @Test func todayOnlyBeforeItsTimeAndNotWhileAWorkoutRuns() {
        let routine = Schedule.mainRoutine()
        let wednesday = Self.at("2026-09-30", 8)
        #expect(Self.planner.plan(Self.input(routine), now: wednesday).first?.date == Self.at("2026-09-30", 9))
        let later = Self.planner.plan(Self.input(routine), now: Self.at("2026-09-30", 9, 1))
        #expect(later.first?.date == Self.at("2026-10-02", 9))
        let running = Self.planner.plan(Self.input(routine, running: true), now: wednesday)
        #expect(running.first?.date == Self.at("2026-10-02", 9))
    }

    @Test func aDayAlreadyDoneGetsNoReminder() {
        let routine = Schedule.mainRoutine()
        var input = Self.input(routine, routineMinutes: [routine.id: 18 * 60])
        input.history.append(
            WorkoutRecord(routineID: routine.id, templateID: Schedule.templateIDs[1], date: Self.at("2026-09-30", 7)))
        let reminders = Self.planner.plan(input, now: Self.at("2026-09-30", 8))
        #expect(reminders.first?.date == Self.at("2026-10-02", 9))
    }

    @Test func routineRemindersAtTheirOwnTime() throws {
        let routine = Schedule.mainRoutine()
        let input = Self.input(routine, morning: nil, routineMinutes: [routine.id: 18 * 60 + 30])
        let reminders = Self.planner.plan(input, now: Self.at("2026-09-29", 20))
        let first = try #require(reminders.first)
        #expect(first.kind == .routine(routine.id) && first.date == Self.at("2026-09-30", 18, 30))
        #expect(first.workoutNames == ["Back & Triceps"])
        #expect(first.id == "peak.reminder.routine.\(routine.id.uuidString).2026-09-30")
        #expect(reminders.count == 6)
    }

    @Test func bothKindsStayUnderTheSystemLimit() {
        let everyday = RoutineSnapshot(
            schedule: .interval(days: 1, start: Schedule.day("2026-09-01")),
            entries: Schedule.templateIDs.map { .init(templateID: $0) })
        let other = Schedule.mainRoutine()
        let input = ReminderInput(
            routines: [everyday, other], history: [], templateNames: Self.names, morningMinutes: 9 * 60,
            routineMinutes: [everyday.id: 7 * 60, other.id: 19 * 60])
        let reminders = Self.planner.plan(input, now: Self.at("2026-09-29", 6))
        // 14 mornings, 14 everyday reminders, 6 for Monday, Wednesday and Friday.
        #expect(reminders.count == 34)
        #expect(zip(reminders, reminders.dropFirst()).allSatisfy { $0.date <= $1.date })
        let many = (0..<5).map { _ in everyday }.map { routine in
            RoutineSnapshot(schedule: routine.schedule, entries: routine.entries)
        }
        let crowded = ReminderInput(
            routines: many, history: [], templateNames: Self.names, morningMinutes: 9 * 60,
            routineMinutes: Dictionary(uniqueKeysWithValues: many.map { ($0.id, 7 * 60) }))
        #expect(Self.planner.plan(crowded, now: Self.at("2026-09-29", 6)).count == ReminderPlanner.limit)
        // One morning reminder a day names both routines' workouts.
        let tuesday = reminders.first { $0.kind == .morning && $0.date == Self.at("2026-09-29", 9) }
        #expect(tuesday?.workoutNames.count == 1)
        let wednesday = reminders.first { $0.kind == .morning && $0.date == Self.at("2026-09-30", 9) }
        #expect(wednesday?.workoutNames.count == 2)
    }

    @Test func nothingWithoutRoutinesOrReminders() {
        let routine = Schedule.mainRoutine()
        #expect(Self.planner.plan(Self.input(routine, morning: nil), now: Self.at("2026-09-29", 8)).isEmpty)
        var inactive = routine
        inactive.isActive = false
        #expect(Self.planner.plan(Self.input(inactive), now: Self.at("2026-09-29", 8)).isEmpty)
    }
}
