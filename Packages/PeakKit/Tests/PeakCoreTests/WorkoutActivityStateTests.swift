import Foundation
import PeakCore
import SwiftData
import Testing

/// F9-03: what the Live Activity shows for the running session.
@MainActor
@Suite struct WorkoutActivityStateTests {
    let start = Date(timeIntervalSinceReferenceDate: 812_450_000)

    func running() throws -> (WorkoutSession, WorkoutSessionController) {
        let context = try makeContext()
        try SampleProgram.install(into: context)
        let template = try #require(try TemplateRepository(context: context).all().first)
        let session = SessionRepository(context: context).start(from: template, at: start)
        return (session, WorkoutSessionController(session: session, context: context))
    }

    @Test func aFreshWorkoutStartsAtTheFirstMovement() throws {
        let (session, _) = try running()
        let state = WorkoutActivityState(session: session, now: start.addingTimeInterval(60))
        #expect(state.timerAnchor == start && !state.isPaused)
        #expect(state.currentExercise == session.orderedExercises.first?.exerciseName)
        #expect(state.completedSets == 0 && state.totalSets == session.setCount && state.progress == 0)
    }

    @Test func setsMovementsAndPausesMoveTheState() throws {
        let (session, controller) = try running()
        let first = try #require(session.orderedExercises.first)
        // Without history there are no targets to fill in: the sets are logged, then the movement completed.
        for set in first.orderedSets {
            try controller.setReps(8, of: set, at: start.addingTimeInterval(200))
        }
        try controller.completeMovement(first, at: start.addingTimeInterval(300))
        try controller.pause(at: start.addingTimeInterval(600))

        let paused = WorkoutActivityState(session: session, now: start.addingTimeInterval(900))
        #expect(paused.currentExercise == session.orderedExercises[1].exerciseName)
        #expect(paused.completedSets == first.orderedSets.count)
        // Paused at ten minutes: the clock stands there however long the pause lasts.
        #expect(paused.pausedElapsed == 600)

        try controller.resume(at: start.addingTimeInterval(1_200))
        let resumed = WorkoutActivityState(session: session, now: start.addingTimeInterval(1_260))
        // Ten paused minutes move the anchor, so the running clock skips them.
        #expect(resumed.timerAnchor == start.addingTimeInterval(600) && !resumed.isPaused)
    }

    @Test func aDoneWorkoutShowsItsLastMovement() throws {
        let (session, controller) = try running()
        for exercise in session.orderedExercises {
            try controller.completeMovement(exercise, at: start.addingTimeInterval(60))
        }
        let state = WorkoutActivityState(session: session, now: start.addingTimeInterval(120))
        #expect(state.currentExercise == session.orderedExercises.last?.exerciseName)
    }
}
