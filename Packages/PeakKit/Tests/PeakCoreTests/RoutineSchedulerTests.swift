import Foundation
import PeakCore
import Testing

@Suite struct RoutineSchedulerTests {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        calendar.firstWeekday = 2  // Monday
        return calendar
    }()

    static let scheduler = RoutineScheduler(calendar: calendar)

    static func day(_ text: String) -> Date {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 18)) ?? .now
    }

    /// The sample program's six templates, in rotation order.
    static let names = [
        "Chest & Biceps", "Back & Triceps", "Shoulder & Biceps", "Chest & Triceps", "Back & Biceps",
        "Shoulder & Triceps",
    ]
    static let templateIDs = names.map { _ in UUID() }
    static func name(_ id: UUID?) -> String? { templateIDs.firstIndex(of: id ?? UUID()).map { names[$0] } }

    static func mainRoutine(archived: Set<Int> = []) -> RoutineSnapshot {
        RoutineSnapshot(
            schedule: .weekdays([.monday, .wednesday, .friday]),
            entries: templateIDs.enumerated().map { .init(templateID: $1, isArchived: archived.contains($0)) }
        )
    }

    /// The real log: … 25.09 Shoulder & Triceps, 28.09 Chest & Biceps.
    static func history(for routine: RoutineSnapshot) -> [WorkoutRecord] {
        [("2026-09-25", 5), ("2026-09-21", 3), ("2026-09-23", 4), ("2026-09-28", 0)].map {
            WorkoutRecord(routineID: routine.id, templateID: templateIDs[$0.1], date: day($0.0))
        }
    }

    func planned(_ routine: RoutineSnapshot, history: [WorkoutRecord], today: String, days: [String])
        -> [String: [String]]
    {
        let plan = Self.scheduler.plan(
            routines: [routine], history: history, days: days.map(Self.day), today: Self.day(today))
        var result: [String: [String]] = [:]
        for text in days {
            let workouts = plan[Self.calendar.startOfDay(for: Self.day(text))] ?? []
            result[text] = workouts.map { "\($0.status == .completed ? "✓" : "")\(Self.name($0.templateID) ?? "?")" }
        }
        return result
    }

    /// Matches the `/coach` skill's upcoming list (Siradaki-Antrenmanlar.md) on 29.09.2026.
    @Test func sixTemplateRotationMatchesCoach() {
        let routine = Self.mainRoutine()
        let week = ["2026-09-28", "2026-09-29", "2026-09-30", "2026-10-01", "2026-10-02", "2026-10-03", "2026-10-04"]
        let plan = planned(routine, history: Self.history(for: routine), today: "2026-09-29", days: week)
        #expect(plan["2026-09-28"] == ["✓Chest & Biceps"])
        #expect(plan["2026-09-29"] == [])
        #expect(plan["2026-09-30"] == ["Back & Triceps"])
        #expect(plan["2026-10-02"] == ["Shoulder & Biceps"])
        #expect(plan["2026-10-01"] == [] && plan["2026-10-03"] == [] && plan["2026-10-04"] == [])

        let next = planned(routine, history: Self.history(for: routine), today: "2026-09-29", days: ["2026-10-05"])
        #expect(next["2026-10-05"] == ["Chest & Triceps"])
        #expect(
            Self.name(Self.scheduler.nextTemplate(for: routine, history: Self.history(for: routine)))
                == "Back & Triceps")
    }

    @Test func rotationWrapsAround() {
        let routine = Self.mainRoutine()
        let history = [
            WorkoutRecord(routineID: routine.id, templateID: Self.templateIDs[5], date: Self.day("2026-09-25"))
        ]
        #expect(Self.name(Self.scheduler.nextTemplate(for: routine, history: history)) == "Chest & Biceps")
        #expect(Self.name(Self.scheduler.nextTemplate(for: routine, history: [])) == "Chest & Biceps")
    }

    /// Missing Wednesday does not skip Back & Triceps: it moves to Friday.
    @Test func missedDayDoesNotSkipAWorkout() {
        let routine = Self.mainRoutine()
        let plan = planned(
            routine, history: Self.history(for: routine), today: "2026-10-01",
            days: ["2026-09-30", "2026-10-01", "2026-10-02", "2026-10-05"])
        #expect(plan["2026-09-30"] == [])
        #expect(plan["2026-10-02"] == ["Back & Triceps"])
        #expect(plan["2026-10-05"] == ["Shoulder & Biceps"])
    }

    @Test func doneTodayShowsCompletedAndMovesOn() {
        let routine = Self.mainRoutine()
        let history =
            Self.history(for: routine)
            + [WorkoutRecord(routineID: routine.id, templateID: Self.templateIDs[1], date: Self.day("2026-09-30"))]
        let plan = planned(routine, history: history, today: "2026-09-30", days: ["2026-09-30", "2026-10-02"])
        #expect(plan["2026-09-30"] == ["✓Back & Triceps"])
        #expect(plan["2026-10-02"] == ["Shoulder & Biceps"])
    }

    @Test func archivedTemplateIsSkipped() {
        let routine = Self.mainRoutine(archived: [1])
        let plan = planned(
            routine, history: Self.history(for: routine), today: "2026-09-29", days: ["2026-09-30", "2026-10-02"])
        #expect(plan["2026-09-30"] == ["Shoulder & Biceps"])
        #expect(plan["2026-10-02"] == ["Chest & Triceps"])
    }

    @Test func archivedTemplateThatWasLastDoneStillMovesForward() {
        let routine = Self.mainRoutine(archived: [0])
        #expect(
            Self.name(Self.scheduler.nextTemplate(for: routine, history: Self.history(for: routine)))
                == "Back & Triceps")
    }

    @Test func intervalEveryOtherDay() {
        let routine = RoutineSnapshot(
            schedule: .interval(days: 2, start: Self.day("2026-09-01")),
            entries: Self.templateIDs.prefix(2).map { .init(templateID: $0) }
        )
        let history = [
            WorkoutRecord(routineID: routine.id, templateID: Self.templateIDs[0], date: Self.day("2026-09-28"))
        ]
        let days = ["2026-09-29", "2026-09-30", "2026-10-01", "2026-10-02"]
        let plan = planned(routine, history: history, today: "2026-09-29", days: days)
        #expect(plan["2026-09-29"] == [])
        #expect(plan["2026-09-30"] == ["Back & Triceps"])
        #expect(plan["2026-10-01"] == [])
        #expect(plan["2026-10-02"] == ["Chest & Biceps"])
    }

    /// Overdue interval workouts land on today instead of piling up.
    @Test func overdueIntervalStartsToday() {
        let routine = RoutineSnapshot(
            schedule: .interval(days: 3, start: Self.day("2026-09-01")),
            entries: [.init(templateID: Self.templateIDs[0])]
        )
        let plan = planned(routine, history: [], today: "2026-09-29", days: ["2026-09-29", "2026-09-30", "2026-10-02"])
        #expect(plan["2026-09-29"] == ["Chest & Biceps"])
        #expect(plan["2026-09-30"] == [])
        #expect(plan["2026-10-02"] == ["Chest & Biceps"])
    }

    @Test func severalRoutinesOnOneDayFollowSortIndex() {
        let walking = RoutineSnapshot(
            sortIndex: 1, schedule: .weekdays([.wednesday]), entries: [.init(templateID: Self.templateIDs[5])])
        let main = Self.mainRoutine()
        let inactive = RoutineSnapshot(
            sortIndex: 2, isActive: false, schedule: .weekdays([.wednesday]),
            entries: [.init(templateID: Self.templateIDs[3])])
        let plan = Self.scheduler.plan(
            routines: [walking, inactive, main], history: Self.history(for: main),
            days: [Self.day("2026-09-30")], today: Self.day("2026-09-29"))
        let wednesday = plan[Self.calendar.startOfDay(for: Self.day("2026-09-30"))] ?? []
        #expect(wednesday.map { Self.name($0.templateID) } == ["Back & Triceps", "Shoulder & Triceps"])
    }

    @Test func weekStartsOnTheCalendarsFirstWeekday() {
        let week = Self.scheduler.week(containing: Self.day("2026-10-01"))
        #expect(week.count == 7)
        #expect(Weekday(of: week[0], calendar: Self.calendar) == .monday)
        #expect(Self.calendar.isDate(week[0], inSameDayAs: Self.day("2026-09-28")))
    }

    @Test func weekdayFromDate() {
        #expect(Weekday(of: Self.day("2026-09-28"), calendar: Self.calendar) == .monday)
        #expect(Weekday(of: Self.day("2026-10-04"), calendar: Self.calendar) == .sunday)
    }
}
