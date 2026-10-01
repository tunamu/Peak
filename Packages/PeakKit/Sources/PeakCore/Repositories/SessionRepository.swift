import Foundation
import SwiftData

/// Workout sessions: starting one from a template, finishing it, and reading history.
///
/// Pause/resume timing and targets belong to `WorkoutSessionController` and `ProgressionEngine`; this type only
/// stores and reads.
@MainActor
public final class SessionRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    /// Starts a session from a template: one exercise per template item, with its number of sets, and a snapshot of
    /// every name.
    ///
    /// Each strength set gets its target (shown in the reps field) from the exercise's last completed performance
    /// through `ProgressionEngine`, and its weight is prefilled with the target weight; reps stay empty until the set
    /// is done.
    /// Without history the targets stay empty.
    @discardableResult
    public func start(
        from template: WorkoutTemplate,
        routine: Routine? = nil,
        rule: ProgressionRule = .init(),
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
                // The movement's own rule, else the workout's, else the app-wide one (F11-10).
                let rule = rule.applying(template.overloadOverride, item.exercise?.overloadOverride)
                let targets = targets(for: item.exercise, setCount: item.targetSets, rule: rule)
                exercise.sets = (0..<item.targetSets).map { order in
                    let set = SetEntry(order: order)
                    if order < targets.count {
                        set.targetWeightKg = targets[order].weightKg
                        set.targetReps = targets[order].reps
                        set.weightKg = targets[order].weightKg
                    }
                    return set
                }
            }
            return exercise
        }
        context.insert(session)
        return session
    }

    private func targets(for exercise: Exercise?, setCount: Int, rule: ProgressionRule) -> [SetTarget] {
        guard let exercise, let last = try? history(of: exercise).first else { return [] }
        return ProgressionEngine.targets(
            after: last.orderedSets.map { SetPerformance(weightKg: $0.weightKg, reps: $0.reps) },
            setCount: setCount,
            incrementKg: exercise.incrementKg,
            rule: rule
        )
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

    /// The movement's latest note from an earlier session ("Seat 4 felt low"), for "Last time" while logging it
    /// (F11-12); `nil` when none has one.
    public func previousNote(before item: SessionExercise) throws -> String? {
        guard let session = item.session else { return nil }
        let key = item.exerciseName.matchingKey
        return try completed()
            .filter { $0.persistentModelID != session.persistentModelID && $0.startedAt < session.startedAt }
            .lazy
            .compactMap { candidate in
                candidate.orderedExercises.first {
                    if let linked = $0.exercise, let exercise = item.exercise {
                        return linked.persistentModelID == exercise.persistentModelID
                    }
                    return $0.exerciseName.matchingKey == key
                }?.note
            }
            .first { !$0.isEmpty }
    }

    /// The sets the movement was last done with before this session: what the set table shows as "Previous". Only
    /// sets with reps count; empty without history. A movement whose exercise is gone matches by name.
    public func previousSets(before item: SessionExercise) throws -> [SetPerformance] {
        guard let session = item.session else { return [] }
        let key = item.exerciseName.matchingKey
        let earlier = try completed().filter {
            $0.persistentModelID != session.persistentModelID && $0.startedAt < session.startedAt
        }
        for candidate in earlier {
            let match = candidate.orderedExercises.first {
                if let linked = $0.exercise, let exercise = item.exercise {
                    return linked.persistentModelID == exercise.persistentModelID
                }
                return $0.exerciseName.matchingKey == key
            }
            let done = (match?.orderedSets ?? []).filter { $0.reps > 0 }
            if !done.isEmpty {
                return done.map { SetPerformance(weightKg: $0.weightKg, reps: $0.reps) }
            }
        }
        return []
    }
}
