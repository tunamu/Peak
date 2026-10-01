import Foundation

/// A completed session as the Analysis screen sees it: plain values, so `PerformanceAnalysis` stays pure and testable
/// without SwiftData (docs/ANALYSIS.md).
public struct AnalysisSession: Hashable, Sendable, Identifiable {
    public var id: UUID
    public var date: Date
    /// The importer dated it (an undated row in a spreadsheet): shown as approximate.
    public var isDateEstimated: Bool
    public var duration: TimeInterval
    public var title: String
    /// The workout template it was started from; `nil` for imported sessions without one.
    public var templateID: UUID?
    public var movements: [AnalysisMovement]

    public init(
        id: UUID = UUID(),
        date: Date,
        isDateEstimated: Bool = false,
        duration: TimeInterval = 0,
        title: String = "",
        templateID: UUID? = nil,
        movements: [AnalysisMovement]
    ) {
        self.id = id
        self.date = date
        self.isDateEstimated = isDateEstimated
        self.duration = duration
        self.title = title
        self.templateID = templateID
        self.movements = movements
    }

    /// The movements as `SessionStatistics` sees them.
    public var results: [ExerciseResult] { movements.map(\.result) }

    public var volumeKg: Double { SessionStatistics.volumeKg(results) }

    /// Strength sets with reps: the sets that were done.
    public var doneSetCount: Int {
        movements.filter { !$0.result.isCardio }.reduce(0) { $0 + $1.result.sets.count { $0.reps > 0 } }
    }
}

/// One movement of a session.
public struct AnalysisMovement: Hashable, Sendable {
    /// Ties the movement's sessions together: the exercise's current name as a `matchingKey`, so a renamed exercise
    /// keeps its history and a session whose exercise is gone matches by the name it was logged under.
    public var key: String
    public var name: String
    public var muscleGroup: MuscleGroup
    public var result: ExerciseResult
    /// A walk's distance, when every segment had a speed and a duration.
    public var distanceKm: Double?
    /// A walk's length, when every segment had a duration.
    public var durationSec: Int?
    /// How it went this time (F11-12).
    public var note: String
    /// How the movement is set up: seat, grip (F11-12).
    public var setupNote: String

    public init(
        name: String,
        muscleGroup: MuscleGroup? = nil,
        result: ExerciseResult,
        distanceKm: Double? = nil,
        durationSec: Int? = nil,
        note: String = "",
        setupNote: String = ""
    ) {
        self.key = name.matchingKey
        self.name = name
        self.muscleGroup = muscleGroup ?? MuscleGroup.inferred(from: name, isCardio: result.isCardio)
        self.result = result
        self.distanceKm = distanceKm
        self.durationSec = durationSec
        self.note = note
        self.setupNote = setupNote
    }
}

extension WorkoutSession {
    /// The session as the Analysis screen sees it.
    public var analysisSession: AnalysisSession {
        AnalysisSession(
            id: id,
            date: startedAt,
            isDateEstimated: isDateEstimated,
            duration: duration(),
            title: title,
            templateID: template?.id,
            movements: zip(orderedExercises, results).map { exercise, result in
                let segments = exercise.orderedSegments
                let seconds = segments.compactMap(\.durationSec)
                return AnalysisMovement(
                    name: exercise.exercise?.name ?? exercise.exerciseName,
                    muscleGroup: exercise.exercise.map(\.muscleGroup).flatMap { $0 == .other ? nil : $0 },
                    result: result,
                    distanceKm: exercise.distanceKm,
                    durationSec: !segments.isEmpty && seconds.count == segments.count ? seconds.reduce(0, +) : nil,
                    note: exercise.note,
                    setupNote: exercise.exercise?.note ?? ""
                )
            }
        )
    }
}
