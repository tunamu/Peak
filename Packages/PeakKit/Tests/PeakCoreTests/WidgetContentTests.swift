import Foundation
import PeakCore
import SwiftData
import Testing

/// F9-01: what the widgets show, built from the shared store, the settings and the Health snapshot.
@MainActor
@Suite struct WidgetContentTests {
    let calendar = Calendar(identifier: .gregorian)

    func settings() throws -> SettingsStore {
        SettingsStore(defaults: try #require(UserDefaults(suiteName: "peak.tests.\(UUID().uuidString)")))
    }

    /// A Monday, the sample routine's first day (Mon/Wed/Fri).
    func monday() throws -> Date {
        try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 9)))
    }

    @Test func plannedWorkoutWaterAndTodaysSnapshot() throws {
        let context = try makeContext()
        try SampleProgram.install(into: context)
        let now = try monday()
        _ = try WaterRepository(context: context, calendar: calendar).add(500, at: now)
        let snapshot = WidgetSnapshot(day: LocalDate(now, calendar: calendar), steps: 4_200, energy: .low)

        let content = try WidgetContent.make(
            context: context, settings: settings(), snapshot: snapshot, now: now, calendar: calendar)
        #expect(content.waterMl == 500 && content.waterGoalMl == 4_000 && content.quickWaterMl == 200)
        #expect(content.steps == 4_200 && content.energy == .low && content.stepGoal == 10_000)
        guard case .planned(let name, let movements, _) = content.workout else {
            Issue.record("\(content.workout)")
            return
        }
        #expect(name == "Chest & Biceps" && movements == 5)
    }

    @Test func yesterdaysSnapshotIsNotShown() throws {
        let now = try monday()
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: now))
        let snapshot = WidgetSnapshot(day: LocalDate(yesterday, calendar: calendar), steps: 9_000, energy: .ready)
        let content = try WidgetContent.make(
            context: makeContext(), settings: settings(), snapshot: snapshot, now: now, calendar: calendar)
        #expect(content.steps == nil && content.energy == nil)
        #expect(content.workout == .none)
    }

    @Test func runningThenFinishedWorkout() throws {
        let context = try makeContext()
        try SampleProgram.install(into: context)
        let now = try monday()
        let template = try #require(try TemplateRepository(context: context).all().first)
        // Started from Home: linked to the routine, so it stands for the day's planned workout.
        let routine = try RoutineRepository(context: context).all().first
        let session = SessionRepository(context: context).start(from: template, routine: routine, at: now)
        try context.save()

        let running = try WidgetContent.make(
            context: context, settings: settings(), snapshot: nil, now: now, calendar: calendar)
        #expect(running.workout == .active(name: template.name, startedAt: now, isPaused: false))

        SessionRepository(context: context).complete(session, at: now.addingTimeInterval(3_000))
        try context.save()
        let done = try WidgetContent.make(
            context: context, settings: settings(), snapshot: nil, now: now.addingTimeInterval(3_600),
            calendar: calendar)
        #expect(done.workout == .completed(name: template.name, duration: 3_000))
    }

    @Test func restDayNamesTheNextWorkout() throws {
        let context = try makeContext()
        try SampleProgram.install(into: context)
        let tuesday = try monday().addingTimeInterval(86_400)
        let content = try WidgetContent.make(
            context: context, settings: settings(), snapshot: nil, now: tuesday, calendar: calendar)
        guard case .rest(let next?) = content.workout else {
            Issue.record("\(content.workout)")
            return
        }
        #expect(calendar.component(.weekday, from: next) == 4)  // Wednesday
    }

    @Test func snapshotRoundTripsThroughAFile() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "snapshot-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let snapshot = WidgetSnapshot(day: LocalDate(year: 2026, month: 10, day: 5), steps: 1_234, energy: .notReady)
        try snapshot.write(to: url)
        #expect(WidgetSnapshot.read(from: url) == snapshot)
        #expect(WidgetSnapshot.read(from: url.appending(path: "missing")) == nil)
    }
}
