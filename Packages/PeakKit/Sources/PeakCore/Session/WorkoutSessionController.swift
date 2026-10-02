import Foundation
import SwiftData

/// The running workout's state machine (§6.4):
///
/// ```
/// active ──pause──► paused ──resume──► active
///   active / paused ──finish──► completed
///   active / paused ──discard──► (deleted)
/// logging ──save──► completed          (entered after the fact, F11-13)
/// logging ──discard──► (deleted)
/// ```
///
/// Every transition is saved at once, so a workout survives the app being killed: on the next launch
/// `SessionRepository.current()` finds it again, still running or still paused, and `openLog()` a half-entered one.
@MainActor
public final class WorkoutSessionController {
    public enum TransitionError: Error, Equatable {
        /// The transition is not allowed from the session's current status, e.g. pausing a paused workout.
        case notAllowed(from: SessionStatus)
    }

    public let session: WorkoutSession
    private let context: ModelContext

    public init(session: WorkoutSession, context: ModelContext) {
        self.session = session
        self.context = context
    }

    public var status: SessionStatus { session.status }

    /// Whether the workout can still change: running, paused, or being entered.
    public var isOpen: Bool { status == .active || status == .paused || status == .logging }

    /// Time spent working out so far; paused time is left out.
    public func elapsed(at date: Date = .now) -> TimeInterval {
        session.duration(now: date)
    }

    public func pause(at date: Date = .now) throws {
        guard status == .active else { throw TransitionError.notAllowed(from: status) }
        session.pausedAt = date
        session.status = .paused
        try context.save()
    }

    public func resume(at date: Date = .now) throws {
        guard status == .paused else { throw TransitionError.notAllowed(from: status) }
        if let pausedAt = session.pausedAt {
            session.pausedTotal += max(0, date.timeIntervalSince(pausedAt))
        }
        session.pausedAt = nil
        session.status = .active
        try context.save()
    }

    /// Sets without reps: Finish asks before ending with any ("3 sets are empty. Finish anyway?").
    public var emptySetCount: Int {
        session.orderedExercises.flatMap(\.orderedSets).count { $0.reps == 0 }
    }

    /// Whether anything was entered: a set's reps, a walk's values, a note or a movement marked done. Cancelling a
    /// workout entered after the fact asks first only then.
    public var hasEntries: Bool {
        session.orderedExercises.contains { exercise in
            exercise.isCompleted || !exercise.note.isEmpty || exercise.orderedSets.contains { $0.reps > 0 }
                || exercise.orderedSegments.contains {
                    $0.speedKmh != nil || $0.inclinePercent != nil || $0.durationSec != nil
                }
        }
    }

    /// Ends the workout. A paused workout ends at the moment it was paused, so the pause is not counted.
    public func finish(at date: Date = .now) throws {
        guard status == .active || status == .paused else { throw TransitionError.notAllowed(from: status) }
        SessionRepository(context: context).complete(session, at: date)
        try context.save()
    }

    // MARK: Entered after the fact (F11-13)

    /// Moves a workout being entered to `start`, lasting `duration`; the day is the caller's to keep.
    public func setLogTime(start: Date, duration: TimeInterval) throws {
        guard status == .logging else { throw TransitionError.notAllowed(from: status) }
        session.startedAt = start
        session.endedAt = start.addingTimeInterval(max(0, duration))
        try context.save()
    }

    /// Saves a workout being entered into the history. Its sets count as done at the workout's end, not now.
    public func saveLog() throws {
        guard status == .logging else { throw TransitionError.notAllowed(from: status) }
        let end = session.endedAt ?? session.startedAt
        for set in session.orderedExercises.flatMap(\.orderedSets) where set.isCompleted {
            set.completedAt = end
        }
        session.endedAt = end
        session.status = .completed
        try context.save()
    }

    /// Throws the workout away with everything logged in it.
    public func discard() throws {
        guard isOpen else { throw TransitionError.notAllowed(from: status) }
        SessionRepository(context: context).discard(session)
        try context.save()
    }

    // MARK: Sets

    /// Stores a weight typed by the user, in kg.
    public func setWeight(_ weightKg: Double, of set: SetEntry) throws {
        try requireOpen()
        set.weightKg = max(0, weightKg)
        try context.save()
    }

    /// Stores the reps; entering reps completes the set, clearing them reopens it.
    public func setReps(_ reps: Int, of set: SetEntry, at date: Date = .now) throws {
        try requireOpen()
        set.reps = max(0, reps)
        set.isCompleted = set.reps > 0
        set.completedAt = set.isCompleted ? date : nil
        try context.save()
    }

    /// Adds a set after the last one with the same weight and target; reps stay empty until it is done.
    @discardableResult
    public func addSet(to exercise: SessionExercise) throws -> SetEntry {
        try requireOpen()
        let sets = exercise.orderedSets
        let set = SetEntry(order: sets.count)
        if let last = sets.last {
            set.weightKg = last.weightKg
            set.targetWeightKg = last.targetWeightKg
            set.targetReps = last.targetReps
        }
        exercise.sets = (exercise.sets ?? []) + [set]
        try context.save()
        return set
    }

    public func deleteSets(at offsets: IndexSet, in exercise: SessionExercise) throws {
        try requireOpen()
        let sets = exercise.orderedSets
        let removed = offsets.map { sets[$0] }
        renumber(sets.enumerated().filter { !offsets.contains($0.offset) }.map(\.element))
        for set in removed {
            context.delete(set)
        }
        try context.save()
    }

    /// Reorders sets by drag and drop (D-11); the numbers follow the new order, the targets move with their sets.
    public func moveSets(from source: IndexSet, to destination: Int, in exercise: SessionExercise) throws {
        try requireOpen()
        // Same semantics as SwiftUI's `move(fromOffsets:toOffset:)`, which PeakCore cannot import.
        let sets = exercise.orderedSets
        let moved = source.map { sets[$0] }
        let before = sets.enumerated().filter { $0.offset < destination && !source.contains($0.offset) }.map(\.element)
        let after = sets.enumerated().filter { $0.offset >= destination && !source.contains($0.offset) }.map(\.element)
        renumber(before + moved + after)
        try context.save()
    }

    // MARK: Walking (C-12)

    /// Stores a segment's speed (km/h), incline (%) and duration (min); `.some(nil)` clears a value, `nil` leaves it.
    /// An empty duration means "the rest of the session".
    public func update(
        _ segment: CardioSegment,
        speedKmh: Double?? = nil,
        inclinePercent: Double?? = nil,
        durationMinutes: Int?? = nil
    ) throws {
        try requireOpen()
        if let speedKmh { segment.speedKmh = speedKmh.map { max(0, $0) } }
        if let inclinePercent { segment.inclinePercent = inclinePercent.map { max(0, $0) } }
        if let durationMinutes { segment.durationSec = durationMinutes.flatMap { $0 > 0 ? $0 * 60 : nil } }
        try context.save()
    }

    /// Adds a segment after the last one with the same speed and incline, and no duration yet.
    @discardableResult
    public func addSegment(to exercise: SessionExercise) throws -> CardioSegment {
        try requireOpen()
        let segments = exercise.orderedSegments
        let segment = CardioSegment(order: segments.count)
        segment.speedKmh = segments.last?.speedKmh
        segment.inclinePercent = segments.last?.inclinePercent
        exercise.segments = (exercise.segments ?? []) + [segment]
        try context.save()
        return segment
    }

    public func deleteSegments(at offsets: IndexSet, in exercise: SessionExercise) throws {
        try requireOpen()
        let segments = exercise.orderedSegments
        let kept = segments.enumerated().filter { !offsets.contains($0.offset) }.map(\.element)
        for (order, segment) in kept.enumerated() {
            segment.order = order
        }
        for offset in offsets {
            context.delete(segments[offset])
        }
        try context.save()
    }

    // MARK: Movements

    /// "Complete Movement": marks the movement done. Sets left empty are completed as planned (their target reps);
    /// a set without a target stays empty, since there is nothing to assume.
    public func completeMovement(_ exercise: SessionExercise, at date: Date = .now) throws {
        try requireOpen()
        for set in exercise.orderedSets where set.reps == 0 {
            guard let targetReps = set.targetReps, targetReps > 0 else { continue }
            if set.weightKg == 0, let targetWeightKg = set.targetWeightKg {
                set.weightKg = targetWeightKg
            }
            set.reps = targetReps
            set.isCompleted = true
            set.completedAt = date
        }
        exercise.isCompleted = true
        try context.save()
    }

    /// Opens a completed movement again; what was logged stays.
    public func reopenMovement(_ exercise: SessionExercise) throws {
        try requireOpen()
        exercise.isCompleted = false
        try context.save()
    }

    /// The first movement after `exercise` that is not done yet, where the sheet scrolls next.
    public func nextOpenMovement(after exercise: SessionExercise) -> SessionExercise? {
        session.orderedExercises.first { $0.order > exercise.order && !$0.isCompleted }
    }

    private func renumber(_ sets: [SetEntry]) {
        for (order, set) in sets.enumerated() {
            set.order = order
        }
    }

    private func requireOpen() throws {
        guard isOpen else { throw TransitionError.notAllowed(from: status) }
    }
}
