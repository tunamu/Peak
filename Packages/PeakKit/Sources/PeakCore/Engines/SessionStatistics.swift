import Foundation

/// One exercise of a session, as the statistics see it.
public struct ExerciseResult: Hashable, Sendable {
    public var name: String
    public var isCardio: Bool
    /// Performed sets; a set with 0 reps was not done.
    public var sets: [SetPerformance]
    /// The targets the session showed, one per planned set; empty when there was no history.
    public var targets: [SetTarget]
    /// For cardio: whether the exercise was marked done.
    public var isCompleted: Bool

    public init(
        name: String,
        isCardio: Bool = false,
        sets: [SetPerformance] = [],
        targets: [SetTarget] = [],
        isCompleted: Bool = false
    ) {
        self.name = name
        self.isCardio = isCardio
        self.sets = sets
        self.targets = targets
        self.isCompleted = isCompleted
    }

    /// Every planned set reached its target. Without targets (first time), any completed work counts.
    public var isSuccessful: Bool {
        if isCardio { return isCompleted }
        let done = sets.filter { $0.reps > 0 }
        guard !targets.isEmpty else { return !done.isEmpty }
        guard done.count >= targets.count else { return false }
        return zip(done, targets).allSatisfy { ProgressionEngine.isSuccessful($0, target: $1) }
    }
}

/// Numbers for the summary sheet and history (docs/PROGRESSIVE_OVERLOAD.md › Success).
public enum SessionStatistics {
    /// Σ weight × reps over strength sets, in kg.
    public static func volumeKg(_ exercises: [ExerciseResult]) -> Double {
        exercises.filter { !$0.isCardio }.flatMap(\.sets).reduce(0) { $0 + $1.weightKg * Double($1.reps) }
    }

    /// Completed sets / all sets (0…1). A cardio exercise counts as one unit.
    public static func completion(_ exercises: [ExerciseResult]) -> Double {
        var done = 0
        var total = 0
        for exercise in exercises {
            if exercise.isCardio {
                total += 1
                done += exercise.isCompleted ? 1 : 0
            } else {
                let planned = max(exercise.sets.count, exercise.targets.count)
                total += planned
                done += exercise.sets.filter { $0.reps > 0 }.count
            }
        }
        return total == 0 ? 0 : Double(done) / Double(total)
    }

    /// Successful exercises / all exercises (0…1): the log's "hedef başarısı".
    public static func successRate(_ exercises: [ExerciseResult]) -> Double {
        guard !exercises.isEmpty else { return 0 }
        return Double(exercises.filter(\.isSuccessful).count) / Double(exercises.count)
    }
}
