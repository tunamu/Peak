import Foundation

/// What the workout's Live Activity shows (C-17), worked out from the running session. Kept apart from ActivityKit
/// (iOS only) so it can be tested on the Mac.
public struct WorkoutActivityState: Codable, Hashable, Sendable {
    /// When the clock would have started had there been no pauses: `Text(timerInterval:)` counts from here.
    public var timerAnchor: Date
    /// The time to show while paused (the clock stands still); `nil` while running.
    public var pausedElapsed: TimeInterval?
    /// The first movement not completed yet, or the last one when all are.
    public var currentExercise: String
    public var completedSets: Int
    public var totalSets: Int

    public init(
        timerAnchor: Date, pausedElapsed: TimeInterval?, currentExercise: String, completedSets: Int, totalSets: Int
    ) {
        self.timerAnchor = timerAnchor
        self.pausedElapsed = pausedElapsed
        self.currentExercise = currentExercise
        self.completedSets = completedSets
        self.totalSets = totalSets
    }

    public var isPaused: Bool { pausedElapsed != nil }

    /// 0…1; a walk without sets counts as its movements done.
    public var progress: Double {
        totalSets > 0 ? Double(completedSets) / Double(totalSets) : 0
    }

    @MainActor
    public init(session: WorkoutSession, now: Date = .now) {
        let exercises = session.orderedExercises
        let sets = exercises.flatMap(\.orderedSets)
        self.init(
            timerAnchor: session.startedAt.addingTimeInterval(session.pausedTotal),
            pausedElapsed: session.status == .paused ? session.duration(now: now) : nil,
            currentExercise: (exercises.first { !$0.isCompleted } ?? exercises.last)?.exerciseName ?? session.title,
            completedSets: sets.filter(\.isCompleted).count,
            totalSets: sets.count
        )
    }

    public static let sample = WorkoutActivityState(
        timerAnchor: .now.addingTimeInterval(-1_520), pausedElapsed: nil, currentExercise: "Lat Pulldown",
        completedSets: 4, totalSets: 11)
}
