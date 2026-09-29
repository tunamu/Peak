import Foundation
import SwiftData

/// Workout sessions: starting one from a template, finishing it, and reading history.
///
/// Pause/resume timing and targets belong to `WorkoutSessionController` and `ProgressionEngine` (F3); this type only
/// stores and reads.
@MainActor
public final class SessionRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    /// Starts a session from a template: one exercise per template item, with its number of empty sets, and a snapshot
    /// of every name.
    @discardableResult
    public func start(
        from template: WorkoutTemplate,
        routine: Routine? = nil,
        at date: Date = .now
    ) -> WorkoutSession {
        let session = WorkoutSession(title: template.name, startedAt: date)
        session.template = template
        session.routine = routine
        session.exercises = template.orderedItems.enumerated().map { index, item in
            let exercise = SessionExercise(order: index, exercise: item.exercise)
            if item.exercise?.kind == .cardio {
                exercise.segments = [CardioSegment(order: 0)]
            } else {
                exercise.sets = (0..<item.targetSets).map { SetEntry(order: $0) }
            }
            return exercise
        }
        context.insert(session)
        return session
    }

    public func complete(_ session: WorkoutSession, at date: Date = .now) {
        if let pausedAt = session.pausedAt {
            session.pausedTotal += date.timeIntervalSince(pausedAt)
            session.pausedAt = nil
        }
        session.endedAt = date
        session.status = .completed
    }

    /// Throws the session away with everything in it.
    public func discard(_ session: WorkoutSession) {
        context.delete(session)
    }

    /// The running or paused session, if any.
    public func current() throws -> WorkoutSession? {
        let completed = SessionStatus.completed.rawValue
        let discarded = SessionStatus.discarded.rawValue
        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.statusRaw != completed && $0.statusRaw != discarded },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Completed sessions, newest first, optionally only those started in `range`.
    public func completed(in range: Range<Date>? = nil) throws -> [WorkoutSession] {
        let completed = SessionStatus.completed.rawValue
        let lower = range?.lowerBound ?? .distantPast
        let upper = range?.upperBound ?? .distantFuture
        return try context.fetch(
            FetchDescriptor<WorkoutSession>(
                predicate: #Predicate {
                    $0.statusRaw == completed && $0.startedAt >= lower && $0.startedAt < upper
                },
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )
        )
    }

    /// The routine's most recent completed session; the rotation continues from its template.
    public func lastCompleted(in routine: Routine) throws -> WorkoutSession? {
        try completed().first { $0.routine?.persistentModelID == routine.persistentModelID }
    }

    /// Every completed performance of an exercise, newest first. Matches the linked exercise, or the name snapshot
    /// when the link is gone.
    public func history(of exercise: Exercise) throws -> [SessionExercise] {
        let key = exercise.name.matchingKey
        return try completed().flatMap { session in
            session.orderedExercises.filter {
                if let linked = $0.exercise {
                    return linked.persistentModelID == exercise.persistentModelID
                }
                return $0.exerciseName.matchingKey == key
            }
        }
    }
}
