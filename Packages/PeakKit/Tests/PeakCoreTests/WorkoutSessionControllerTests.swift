import Foundation
import PeakCore
import SwiftData
import Testing

@MainActor
@Suite struct WorkoutSessionControllerTests {
    private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func makeSession(in context: ModelContext) throws -> WorkoutSession {
        let exercises = ExerciseRepository(context: context)
        let templates = TemplateRepository(context: context)
        let template = try templates.create(name: "Chest & Biceps")
        templates.setItems([(try exercises.findOrCreate(name: "Bench Press"), 3)], of: template)
        let session = SessionRepository(context: context).start(from: template, at: start)
        try context.save()
        return session
    }

    @Test func pausedTimeIsLeftOutOfElapsed() throws {
        let context = try makeContext()
        let controller = WorkoutSessionController(session: try makeSession(in: context), context: context)

        try controller.pause(at: start + 600)
        #expect(controller.status == .paused)
        #expect(controller.elapsed(at: start + 900) == 600)

        try controller.resume(at: start + 900)
        #expect(controller.status == .active)
        #expect(controller.elapsed(at: start + 1000) == 700)
    }

    @Test func finishingWhilePausedEndsAtThePause() throws {
        let context = try makeContext()
        let controller = WorkoutSessionController(session: try makeSession(in: context), context: context)

        try controller.pause(at: start + 1200)
        try controller.finish(at: start + 5000)
        #expect(controller.status == .completed)
        #expect(controller.elapsed(at: start + 9000) == 1200)
        #expect(try SessionRepository(context: context).current() == nil)
    }

    @Test func invalidTransitionsThrowAndChangeNothing() throws {
        let context = try makeContext()
        let controller = WorkoutSessionController(session: try makeSession(in: context), context: context)

        #expect(throws: WorkoutSessionController.TransitionError.notAllowed(from: .active)) {
            try controller.resume(at: start + 10)
        }
        try controller.finish(at: start + 60)
        #expect(throws: WorkoutSessionController.TransitionError.notAllowed(from: .completed)) {
            try controller.pause(at: start + 70)
        }
        #expect(throws: WorkoutSessionController.TransitionError.notAllowed(from: .completed)) {
            try controller.discard()
        }
        #expect(controller.elapsed() == 60)
    }

    @Test func discardDeletesTheSession() throws {
        let context = try makeContext()
        try WorkoutSessionController(session: try makeSession(in: context), context: context).discard()
        #expect(try context.fetch(FetchDescriptor<WorkoutSession>()).isEmpty)
    }

    /// F6-01: killing the app does not lose the workout. Each transition is saved, so a fresh container on the same
    /// file (a new launch) finds the session in the state it was left in.
    @Test func sessionSurvivesReopeningTheStore() throws {
        let url = URL.temporaryDirectory.appending(path: "peak-\(UUID().uuidString).store")
        defer {
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(at: URL(filePath: url.path() + suffix))
            }
        }

        do {
            let container = try PeakStore.makeContainer(.file(url))
            let context = ModelContext(container)
            let controller = WorkoutSessionController(session: try makeSession(in: context), context: context)
            try controller.pause(at: start + 300)
            try controller.resume(at: start + 400)
            try controller.pause(at: start + 1000)
        }

        let container = try PeakStore.makeContainer(.file(url))
        let context = ModelContext(container)
        let session = try #require(try SessionRepository(context: context).current())
        #expect(session.title == "Chest & Biceps")
        #expect(session.status == .paused)
        #expect(session.orderedExercises.first?.orderedSets.count == 3)
        #expect(session.duration(now: start + 5000) == 900)

        let controller = WorkoutSessionController(session: session, context: context)
        try controller.resume(at: start + 2000)
        #expect(controller.elapsed(at: start + 2100) == 1000)
    }
}

@MainActor
@Suite struct WorkoutSessionSetTests {
    /// A template with one exercise of `sets` sets, and a controller on a fresh session of it.
    private func makeController(sets: Int = 3) throws -> (WorkoutSessionController, SessionExercise) {
        let context = try makeContext()
        let exercises = ExerciseRepository(context: context)
        let templates = TemplateRepository(context: context)
        let template = try templates.create(name: "Chest & Biceps")
        templates.setItems([(try exercises.findOrCreate(name: "Bench Press"), sets)], of: template)
        let session = SessionRepository(context: context).start(from: template)
        try context.save()
        let controller = WorkoutSessionController(session: session, context: context)
        return (controller, try #require(session.orderedExercises.first))
    }

    @Test func startTakesTargetsFromTheLastPerformance() throws {
        let context = try makeContext()
        let exercises = ExerciseRepository(context: context)
        let bench = try exercises.findOrCreate(name: "Bench Press")
        let templates = TemplateRepository(context: context)
        let template = try templates.create(name: "Chest & Biceps")
        templates.setItems([(bench, 3)], of: template)
        let sessions = SessionRepository(context: context)

        let first = sessions.start(from: template, at: .now.addingTimeInterval(-86_400))
        let controller = WorkoutSessionController(session: first, context: context)
        for (set, reps) in zip(try #require(first.orderedExercises.first).orderedSets, [13, 10, 8]) {
            try controller.setWeight(27.5, of: set)
            try controller.setReps(reps, of: set)
        }
        try controller.finish()

        let sets = try #require(sessions.start(from: template).orderedExercises.first).orderedSets
        #expect(sets.map(\.targetWeightKg) == [30, 27.5, 27.5])
        #expect(sets.map(\.targetReps) == [6, 10, 8])
        #expect(sets.map(\.weightKg) == [30, 27.5, 27.5])
        #expect(sets.allSatisfy { $0.reps == 0 && !$0.isCompleted })
    }

    @Test func firstSessionHasNoTargets() throws {
        let (_, exercise) = try makeController()
        #expect(exercise.orderedSets.allSatisfy { $0.targetWeightKg == nil && $0.weightKg == 0 })
    }

    @Test func repsCompleteASetAndClearingReopensIt() throws {
        let (controller, exercise) = try makeController()
        let set = try #require(exercise.orderedSets.first)
        try controller.setReps(8, of: set)
        #expect(set.isCompleted && set.completedAt != nil)
        #expect(abs(controller.session.completion - 1.0 / 3) < 0.001)
        try controller.setReps(0, of: set)
        #expect(!set.isCompleted && set.completedAt == nil)
    }

    @Test func addSetCopiesTheLastSet() throws {
        let (controller, exercise) = try makeController(sets: 1)
        try controller.setWeight(40, of: try #require(exercise.orderedSets.first))
        let added = try controller.addSet(to: exercise)
        #expect(added.order == 1 && added.weightKg == 40 && added.reps == 0)
        #expect(controller.session.setCount == 2)
    }

    @Test func deleteAndMoveRenumberTheSets() throws {
        let (controller, exercise) = try makeController(sets: 4)
        for (set, weight) in zip(exercise.orderedSets, [10.0, 20, 30, 40]) {
            try controller.setWeight(weight, of: set)
        }
        try controller.moveSets(from: [0], to: 3, in: exercise)
        #expect(exercise.orderedSets.map(\.weightKg) == [20, 30, 10, 40])
        try controller.moveSets(from: [3], to: 0, in: exercise)
        #expect(exercise.orderedSets.map(\.weightKg) == [40, 20, 30, 10])
        try controller.deleteSets(at: [1], in: exercise)
        #expect(exercise.orderedSets.map(\.weightKg) == [40, 30, 10])
        #expect(exercise.orderedSets.map(\.order) == [0, 1, 2])
    }

    @Test func aFinishedSessionCannotBeEdited() throws {
        let (controller, exercise) = try makeController()
        try controller.finish()
        #expect(throws: WorkoutSessionController.TransitionError.notAllowed(from: .completed)) {
            try controller.addSet(to: exercise)
        }
    }
}

@MainActor
@Suite struct CompleteMovementTests {
    private func makeController() throws -> WorkoutSessionController {
        let context = try makeContext()
        let exercises = ExerciseRepository(context: context)
        let templates = TemplateRepository(context: context)
        let template = try templates.create(name: "Back & Triceps")
        templates.setItems(
            [(try exercises.findOrCreate(name: "Row"), 2), (try exercises.findOrCreate(name: "Pushdown"), 2)],
            of: template
        )
        let session = SessionRepository(context: context).start(from: template)
        try context.save()
        return WorkoutSessionController(session: session, context: context)
    }

    @Test func completingFillsEmptySetsWithTheirTargets() throws {
        let controller = try makeController()
        let row = try #require(controller.session.orderedExercises.first)
        let sets = row.orderedSets
        sets[0].targetWeightKg = 50
        sets[0].targetReps = 8
        sets[1].targetWeightKg = 50
        sets[1].targetReps = 8
        try controller.setWeight(52.5, of: sets[0])
        try controller.setReps(10, of: sets[0])

        try controller.completeMovement(row)
        #expect(row.isCompleted)
        #expect(sets.map(\.reps) == [10, 8])
        #expect(sets.map(\.weightKg) == [52.5, 50])
        #expect(sets.allSatisfy { $0.isCompleted })
        #expect(controller.session.completion == 0.5)
        #expect(controller.nextOpenMovement(after: row)?.exerciseName == "Pushdown")
    }

    @Test func setsWithoutTargetsStayEmptyAndReopeningKeepsTheLog() throws {
        let controller = try makeController()
        let row = try #require(controller.session.orderedExercises.first)
        try controller.setReps(12, of: row.orderedSets[0])

        try controller.completeMovement(row)
        #expect(row.orderedSets.map(\.reps) == [12, 0])
        #expect(controller.session.completion == 0.25)

        try controller.reopenMovement(row)
        #expect(!row.isCompleted)
        #expect(row.orderedSets.map(\.reps) == [12, 0])
    }

    @Test func emptySetsAreCountedForTheFinishWarning() throws {
        let controller = try makeController()
        #expect(controller.emptySetCount == 4)
        try controller.setReps(8, of: try #require(controller.session.orderedExercises.first?.orderedSets.first))
        #expect(controller.emptySetCount == 3)
    }

    @Test func nextOpenMovementSkipsCompletedOnes() throws {
        let controller = try makeController()
        let movements = controller.session.orderedExercises
        try controller.completeMovement(movements[1])
        #expect(controller.nextOpenMovement(after: movements[0]) == nil)
    }
}

@MainActor
@Suite struct WalkingTests {
    private func makeController() throws -> (WorkoutSessionController, SessionExercise) {
        let context = try makeContext()
        let walk = try ExerciseRepository(context: context).findOrCreate(name: "Incline Walk", kind: .cardio)
        let templates = TemplateRepository(context: context)
        let template = try templates.create(name: "Walking", kind: .cardio)
        templates.setItems([(walk, 1)], of: template)
        let session = SessionRepository(context: context).start(from: template)
        try context.save()
        let controller = WorkoutSessionController(session: session, context: context)
        return (controller, try #require(session.orderedExercises.first))
    }

    @Test func speedInclineAndDurationAreStored() throws {
        let (controller, walk) = try makeController()
        let segment = try #require(walk.orderedSegments.first)
        try controller.update(segment, speedKmh: 5.5, inclinePercent: 12, durationMinutes: 30)
        #expect(segment.speedKmh == 5.5 && segment.inclinePercent == 12 && segment.durationSec == 1_800)

        try controller.update(segment, durationMinutes: .some(nil))
        #expect(segment.durationSec == nil)
        #expect(segment.speedKmh == 5.5)
    }

    @Test func distanceNeedsEveryDuration() throws {
        let (controller, walk) = try makeController()
        let first = try #require(walk.orderedSegments.first)
        try controller.update(first, speedKmh: 6, inclinePercent: 10, durationMinutes: 20)
        #expect(walk.distanceKm == 2)

        let second = try controller.addSegment(to: walk)
        #expect(second.speedKmh == 6 && second.inclinePercent == 10 && second.durationSec == nil)
        #expect(walk.distanceKm == nil)

        try controller.update(second, speedKmh: 4.5, durationMinutes: 40)
        #expect(walk.distanceKm == 5)
    }

    @Test func deletingRenumbersAndAWalkCountsAsOneUnit() throws {
        let (controller, walk) = try makeController()
        try controller.addSegment(to: walk)
        try controller.addSegment(to: walk)
        try controller.deleteSegments(at: [0], in: walk)
        #expect(walk.orderedSegments.map(\.order) == [0, 1])

        #expect(controller.session.completion == 0)
        try controller.completeMovement(walk)
        #expect(controller.session.completion == 1)
    }
}

@MainActor
@Suite struct WorkoutSummaryTests {
    @Test func summaryReportsVolumeSuccessAndRisingTargets() throws {
        let context = try makeContext()
        let exercises = ExerciseRepository(context: context)
        let templates = TemplateRepository(context: context)
        let template = try templates.create(name: "Chest & Biceps")
        templates.setItems(
            [(try exercises.findOrCreate(name: "Bench Press"), 2), (try exercises.findOrCreate(name: "Curl"), 1)],
            of: template
        )
        let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let session = SessionRepository(context: context).start(from: template, at: start)
        let controller = WorkoutSessionController(session: session, context: context)
        let bench = session.orderedExercises[0].orderedSets
        let curl = session.orderedExercises[1].orderedSets
        for (set, reps) in zip(bench, [13, 10]) {
            try controller.setWeight(27.5, of: set)
            try controller.setReps(reps, of: set)
        }
        try controller.setWeight(10, of: curl[0])
        try controller.setReps(8, of: curl[0])
        try controller.pause(at: start + 1_500)
        try controller.resume(at: start + 1_800)
        try controller.finish(at: start + 2_700)

        let summary = WorkoutSummary(session: session)
        #expect(summary.duration == 2_400)
        #expect(summary.volumeKg == 27.5 * 23 + 80)
        #expect(summary.successRate == 1)
        #expect(summary.risingTargets == [.init(name: "Bench Press", fromKg: 27.5, toKg: 30)])

        let workout = try #require(session.healthWorkout)
        #expect(workout.start == start && workout.end == start + 2_700 && workout.pausedDuration == 300)
        #expect(!workout.isWalk && workout.distanceKm == nil)
    }

    @Test func aWalkIsSavedAsWalkingWithItsDistance() async throws {
        let context = try makeContext()
        let walk = try ExerciseRepository(context: context).findOrCreate(name: "Incline Walk", kind: .cardio)
        let templates = TemplateRepository(context: context)
        let template = try templates.create(name: "Walking", kind: .cardio)
        templates.setItems([(walk, 1)], of: template)
        let session = SessionRepository(context: context).start(from: template)
        let controller = WorkoutSessionController(session: session, context: context)
        #expect(session.healthWorkout == nil)

        let segment = try #require(session.orderedExercises.first?.orderedSegments.first)
        try controller.update(segment, speedKmh: 6, durationMinutes: 30)
        try controller.finish()

        let workout = try #require(session.healthWorkout)
        #expect(workout.isWalk && workout.distanceKm == 3)
        let health = MockHealthService()
        _ = try await health.saveWorkout(workout)
        #expect(health.savedWorkouts == [workout])
    }
}
