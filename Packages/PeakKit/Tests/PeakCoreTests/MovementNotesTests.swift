import Foundation
import PeakCore
import SwiftData
import Testing

/// F11-12: a movement's setup note and its notes session by session.
@MainActor
@Suite struct MovementNotesTests {
    @Test func lastTimesNoteAndTheNotesOverTime() throws {
        let context = try makeContext()
        let row = try ExerciseRepository(context: context).findOrCreate(name: "Row")
        row.note = "Seat 4, chest on the pad"
        let templates = TemplateRepository(context: context)
        let template = try templates.create(name: "Pull")
        templates.setItems([(row, 1)], of: template)
        let sessions = SessionRepository(context: context)
        let start = Date(timeIntervalSinceReferenceDate: 812_000_000)

        for (day, note) in [(0, "Felt light"), (2, ""), (4, "Grip slipped")] {
            let session = sessions.start(from: template, at: start.addingTimeInterval(Double(day) * 86_400))
            let movement = try #require(session.orderedExercises.first)
            movement.note = note
            movement.orderedSets.first?.reps = 10
            movement.orderedSets.first?.weightKg = 50
            sessions.complete(session, at: session.startedAt.addingTimeInterval(3_600))
        }
        let current = sessions.start(from: template, at: start.addingTimeInterval(6 * 86_400))
        try context.save()

        let item = try #require(current.orderedExercises.first)
        #expect(try sessions.previousNote(before: item) == "Grip slipped")

        let movement = try #require(
            PerformanceAnalysis.movements(in: sessions.completed().map(\.analysisSession)).first)
        #expect(movement.setupNote == "Seat 4, chest on the pad")
        #expect(movement.notes.map(\.note) == ["Grip slipped", "Felt light"])
    }

    @Test func noNoteBeforeTheFirstSession() throws {
        let context = try makeContext()
        let row = try ExerciseRepository(context: context).findOrCreate(name: "Row")
        let template = try TemplateRepository(context: context).create(name: "Pull")
        TemplateRepository(context: context).setItems([(row, 1)], of: template)
        let session = SessionRepository(context: context).start(from: template)
        #expect(
            try SessionRepository(context: context).previousNote(before: #require(session.orderedExercises.first))
                == nil)
    }
}
