import Foundation
import PeakCore
import SwiftData
import Testing

/// F11-10: progressive overload per workout and per movement, over the app-wide rule.
@MainActor
@Suite struct OverloadOverrideTests {
    @Test func theMovementWinsOverTheWorkoutOverTheSettings() {
        let settings = ProgressionRule(thresholdReps: 12, resetReps: 6, repStep: 1)
        let workout = OverloadOverride(thresholdReps: 10, repStep: 2)
        let movement = OverloadOverride(thresholdReps: 15)
        #expect(settings.applying(workout, movement) == ProgressionRule(thresholdReps: 15, resetReps: 6, repStep: 2))
        #expect(settings.applying(workout) == ProgressionRule(thresholdReps: 10, resetReps: 6, repStep: 2))
        #expect(settings.applying(nil, OverloadOverride()) == settings)
        // Out of range values are clamped as in Settings.
        #expect(settings.applying(OverloadOverride(thresholdReps: 40, resetReps: 1, repStep: 9)) == .init(20, 6, 5))
    }

    /// The same history (Row 50 × 9) gives each movement its own next target.
    @Test func startingAWorkoutUsesEachMovementsRule() throws {
        let context = try makeContext()
        let exercises = ExerciseRepository(context: context)
        let templates = TemplateRepository(context: context)
        let row = try exercises.findOrCreate(name: "Row")
        let curl = try exercises.findOrCreate(name: "Curl")
        let template = try templates.create(name: "Pull")
        templates.setItems([(row, 1), (curl, 1)], of: template)
        let sessions = SessionRepository(context: context)
        let first = sessions.start(from: template)
        for set in first.orderedExercises.flatMap(\.orderedSets) {
            set.weightKg = 50
            set.reps = 9
        }
        sessions.complete(first)
        try context.save()

        // The workout keeps the weight at 9 reps (step 0); Curl adds 3 reps instead.
        template.overloadOverride = OverloadOverride(repStep: 0)
        curl.overloadOverride = OverloadOverride(repStep: 3)
        let next = sessions.start(from: template)
        let targets = next.orderedExercises.map { $0.orderedSets.first?.targetReps }
        #expect(targets == [9, 12])

        // A movement past its own lower threshold goes up in weight.
        row.overloadOverride = OverloadOverride(thresholdReps: 8, resetReps: 7)
        let third = sessions.start(from: template)
        #expect(third.orderedExercises.first?.orderedSets.first?.targetReps == 7)
        #expect((third.orderedExercises.first?.orderedSets.first?.targetWeightKg ?? 0) > 50)
    }
}

extension ProgressionRule {
    fileprivate init(_ threshold: Int, _ reset: Int, _ step: Int) {
        self.init(thresholdReps: threshold, resetReps: reset, repStep: step)
    }
}
