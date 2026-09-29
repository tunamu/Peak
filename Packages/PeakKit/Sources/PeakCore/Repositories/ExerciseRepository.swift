import Foundation
import SwiftData

/// The movement library. Exercises are archived, never deleted, so past sessions keep their link.
@MainActor
public final class ExerciseRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    /// Exercises sorted by name; archived ones only when asked.
    public func all(includingArchived: Bool = false) throws -> [Exercise] {
        let descriptor = FetchDescriptor<Exercise>(
            predicate: includingArchived ? nil : #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor)
    }

    /// The exercise with this name, ignoring case and accents. Archived ones count, so importing old data relinks
    /// to them instead of creating duplicates.
    public func find(named name: String) throws -> Exercise? {
        let key = name.matchingKey
        return try all(includingArchived: true).first { $0.name.matchingKey == key }
    }

    /// Creates an exercise, or returns the existing one with the same name (uniqueness is enforced here, not by
    /// the store, because CloudKit does not allow unique constraints).
    @discardableResult
    public func findOrCreate(
        name: String,
        muscleGroup: MuscleGroup = .other,
        kind: ExerciseKind = .strength,
        equipment: Equipment = .other,
        incrementKg: Double = 2.5
    ) throws -> Exercise {
        if let existing = try find(named: name) {
            existing.isArchived = false
            return existing
        }
        let exercise = Exercise(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
        exercise.muscleGroup = muscleGroup
        exercise.kind = kind
        exercise.equipment = equipment
        exercise.incrementKg = incrementKg
        context.insert(exercise)
        return exercise
    }

    public func archive(_ exercise: Exercise) {
        exercise.isArchived = true
    }
}
