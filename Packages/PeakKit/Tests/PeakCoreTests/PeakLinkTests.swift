import Foundation
import PeakCore
import SwiftData
import Testing

/// F9-04: the `peak://` links and what "today's workout" means for a shortcut.
@MainActor
@Suite struct PeakLinkTests {
    func url(_ string: String) throws -> URL {
        try #require(URL(string: string))
    }

    @Test func everyLinkReadsBack() {
        for link in PeakLink.allCases {
            #expect(PeakLink(url: link.url) == link)
        }
    }

    /// The exact links the widgets and the Live Activity used before `PeakLink` existed.
    @Test func theWidgetLinksAreRead() throws {
        #expect(PeakLink(url: try url("peak://home")) == .home)
        #expect(PeakLink(url: try url("peak://workout/start")) == .startWorkout)
        #expect(PeakLink(url: try url("peak://workout/open")) == .openWorkout)
    }

    @Test func caseAndATrailingSlashDoNotMatter() throws {
        #expect(PeakLink(url: try url("PEAK://Workout/Start/")) == .startWorkout)
        #expect(PeakLink(url: try url("peak://settings/")) == .settings)
    }

    @Test func otherLinksAreIgnored() throws {
        #expect(PeakLink(url: try url("https://home")) == nil)
        #expect(PeakLink(url: try url("peak://workout")) == nil)
        #expect(PeakLink(url: try url("peak://workout/delete")) == nil)
        #expect(PeakLink(url: try url("peak://")) == nil)
    }

    @Test func todaysWorkoutIsTheRunningOneThenThePlannedOne() throws {
        let context = try makeContext()
        let calendar = Calendar(identifier: .gregorian)
        let monday = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 28, hour: 9)))
        let planner = DayPlanner(calendar: calendar)
        #expect(try planner.nextWorkoutToday(in: context, now: monday) == nil)

        try SampleProgram.install(into: context)
        guard case .planned(let template, let routine)? = try planner.nextWorkoutToday(in: context, now: monday) else {
            Issue.record("Monday is a workout day in the sample routine")
            return
        }
        #expect(template.name == "Chest & Biceps")
        #expect(routine?.name == "Main Routine")

        let session = SessionRepository(context: context).start(from: template, routine: routine, at: monday)
        try context.save()
        #expect(try planner.nextWorkoutToday(in: context, now: monday) == .active(session))

        // Tuesday is a rest day.
        let tuesday = monday.addingTimeInterval(86_400)
        SessionRepository(context: context).complete(session, at: monday.addingTimeInterval(3_600))
        try context.save()
        #expect(try planner.nextWorkoutToday(in: context, now: tuesday) == nil)
    }
}
