import Foundation
import SwiftData

/// Merges library records that two devices created separately before iCloud brought them together (F8-02), such as
/// the sample program loaded on both, or "Row" added on each while offline. CloudKit has no unique constraints, so
/// this is how the store stays free of duplicates.
///
/// Every device runs it after each iCloud import and must reach the same result without talking to the others:
/// - The survivor of a group is the oldest, so a movement's own settings and name win over a copy just made on
///   another device. Age is `createdAt` in whole seconds, because CloudKit keeps only milliseconds and the same record
///   can carry a slightly different date on each device; within the same second the smallest `id` wins (ids sync
///   unchanged). If two devices picked different survivors, each would delete the other's and both would be lost.
/// - Copies with the same `id` as the survivor are left alone: nothing tells them apart the same way on every device.
/// - A group is only what is certainly the same thing: exercises by name; templates by name, kind and their exercise
///   list; routines by name, schedule and rotation. Two different "Push" templates both stay.
///
/// Sessions and water logs are not merged. Each one is an event, and two identical ones on a day can be real.
@MainActor
public enum Deduplicator {
    /// How many duplicates were merged into a survivor and deleted.
    public struct Result: Equatable, Sendable {
        public var exercises = 0
        public var templates = 0
        public var routines = 0

        public var total: Int { exercises + templates + routines }

        public init(exercises: Int = 0, templates: Int = 0, routines: Int = 0) {
            self.exercises = exercises
            self.templates = templates
            self.routines = routines
        }
    }

    /// Merges every duplicate group and saves. Exercises go first, so templates that differed only by which copy of
    /// an exercise they used are recognized as the same; templates go before routines for the same reason.
    @discardableResult
    public static func run(in context: ModelContext) throws -> Result {
        var result = Result()
        result.exercises = try mergeExercises(in: context)
        result.templates = try mergeTemplates(in: context)
        result.routines = try mergeRoutines(in: context)
        if result.total > 0 {
            try context.save()
        }
        return result
    }

    // MARK: Groups

    private static func mergeExercises(in context: ModelContext) throws -> Int {
        let groups = Dictionary(grouping: try context.fetch(FetchDescriptor<Exercise>())) { $0.name.matchingKey }
        return merge(groups, id: \.id, createdAt: \.createdAt, in: context) { survivor, duplicate in
            for item in duplicate.templateItems ?? [] { item.exercise = survivor }
            for sessionExercise in duplicate.sessionExercises ?? [] { sessionExercise.exercise = survivor }
            survivor.isArchived = survivor.isArchived && duplicate.isArchived
        }
    }

    private static func mergeTemplates(in context: ModelContext) throws -> Int {
        let groups = Dictionary(grouping: try context.fetch(FetchDescriptor<WorkoutTemplate>())) { template in
            let items = template.orderedItems.map { "\($0.exercise?.id.uuidString ?? "-")x\($0.targetSets)" }
            return "\(template.name.matchingKey)|\(template.kindRaw)|\(items.joined(separator: ","))"
        }
        return merge(groups, id: \.id, createdAt: \.createdAt, in: context) { survivor, duplicate in
            for entry in duplicate.routineEntries ?? [] { entry.template = survivor }
            for session in duplicate.sessions ?? [] { session.template = survivor }
            survivor.isArchived = survivor.isArchived && duplicate.isArchived
        }
    }

    private static func mergeRoutines(in context: ModelContext) throws -> Int {
        // The start date is left out: an interval routine takes "now" when it is created, different on each device.
        let groups = Dictionary(grouping: try context.fetch(FetchDescriptor<Routine>())) { routine in
            let rotation = routine.orderedEntries.map { $0.template?.id.uuidString ?? "-" }
            return [
                routine.name.matchingKey, routine.scheduleTypeRaw, "\(routine.weekdaysMask)", "\(routine.intervalDays)",
                rotation.joined(separator: ","),
            ].joined(separator: "|")
        }
        return merge(groups, id: \.id, createdAt: \.createdAt, in: context) { survivor, duplicate in
            for session in duplicate.sessions ?? [] { session.routine = survivor }
            survivor.isActive = survivor.isActive || duplicate.isActive
        }
    }

    /// Moves each duplicate's links to the survivor with `absorb`, then deletes the duplicate (its own children, such
    /// as a template's items, go with it). Returns how many were deleted.
    private static func merge<Model: PersistentModel>(
        _ groups: [String: [Model]],
        id: KeyPath<Model, UUID>,
        createdAt: KeyPath<Model, Date>,
        in context: ModelContext,
        absorb: (_ survivor: Model, _ duplicate: Model) -> Void
    ) -> Int {
        var deleted = 0
        for members in groups.values where members.count > 1 {
            let sorted = members.sorted {
                let first = $0[keyPath: createdAt].timeIntervalSinceReferenceDate.rounded(.down)
                let second = $1[keyPath: createdAt].timeIntervalSinceReferenceDate.rounded(.down)
                return first != second ? first < second : $0[keyPath: id].uuidString < $1[keyPath: id].uuidString
            }
            let survivor = sorted[0]
            for duplicate in sorted.dropFirst() where duplicate[keyPath: id] != survivor[keyPath: id] {
                absorb(survivor, duplicate)
                context.delete(duplicate)
                deleted += 1
            }
        }
        return deleted
    }
}
