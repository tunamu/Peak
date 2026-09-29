import Foundation

/// S-11: what a finished workout amounts to. Duration, volume, how many movements hit their targets, and the weights
/// that go up next time.
public struct WorkoutSummary: Hashable, Sendable {
    /// A movement whose next target weight is above what was lifted today: "Bench Press 27.5 → 30 kg".
    public struct RisingTarget: Hashable, Sendable {
        public var name: String
        public var fromKg: Double
        public var toKg: Double

        public init(name: String, fromKg: Double, toKg: Double) {
            self.name = name
            self.fromKg = fromKg
            self.toKg = toKg
        }
    }

    public var title: String
    public var duration: TimeInterval
    public var volumeKg: Double
    /// Movements that reached every target (0…1).
    public var successRate: Double
    /// Completed sets / all sets (0…1).
    public var completion: Double
    public var risingTargets: [RisingTarget]
    /// The walks' distance, when every segment had a duration.
    public var distanceKm: Double?

    public init(
        title: String,
        duration: TimeInterval,
        volumeKg: Double,
        successRate: Double,
        completion: Double,
        risingTargets: [RisingTarget] = [],
        distanceKm: Double? = nil
    ) {
        self.title = title
        self.duration = duration
        self.volumeKg = volumeKg
        self.successRate = successRate
        self.completion = completion
        self.risingTargets = risingTargets
        self.distanceKm = distanceKm
    }

    @MainActor
    public init(session: WorkoutSession, rule: ProgressionRule = .init()) {
        let results = session.results
        title = session.title
        duration = session.duration()
        volumeKg = SessionStatistics.volumeKg(results)
        successRate = SessionStatistics.successRate(results)
        completion = SessionStatistics.completion(results)
        distanceKm = session.walkDistanceKm
        risingTargets = session.orderedExercises.compactMap { exercise in
            guard !exercise.isCardio else { return nil }
            let done = exercise.orderedSets.filter { $0.reps > 0 }.map {
                SetPerformance(weightKg: $0.weightKg, reps: $0.reps)
            }
            let next = ProgressionEngine.targets(
                after: done,
                setCount: exercise.orderedSets.count,
                incrementKg: exercise.exercise?.incrementKg ?? 2.5,
                rule: rule
            )
            guard let from = done.map(\.weightKg).max(), let to = next.map(\.weightKg).max(), to > from + 0.000_1
            else { return nil }
            return RisingTarget(name: exercise.exerciseName, fromKg: from, toKg: to)
        }
    }
}

extension WorkoutSession {
    /// Distance of the walks in the session; `nil` without walks or when a segment has no duration.
    public var walkDistanceKm: Double? {
        let walks = orderedExercises.filter(\.isCardio)
        guard !walks.isEmpty else { return nil }
        let distances = walks.map(\.distanceKm)
        guard distances.allSatisfy({ $0 != nil }) else { return nil }
        return distances.compactMap(\.self).reduce(0, +)
    }

    /// The finished workout for Health; `nil` until the session is completed.
    public var healthWorkout: HealthWorkout? {
        guard status == .completed, let endedAt else { return nil }
        let exercises = orderedExercises
        return HealthWorkout(
            start: startedAt,
            end: endedAt,
            pausedDuration: pausedTotal,
            isWalk: !exercises.isEmpty && exercises.allSatisfy(\.isCardio),
            distanceKm: walkDistanceKm
        )
    }
}
