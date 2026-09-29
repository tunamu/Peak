import Foundation
import SwiftData

/// Routines: which templates rotate, and on which days.
@MainActor
public final class RoutineRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func all() throws -> [Routine] {
        try context.fetch(FetchDescriptor<Routine>(sortBy: [SortDescriptor(\.sortIndex), SortDescriptor(\.createdAt)]))
    }

    /// Active routines; several can be active at once (D-15).
    public func active() throws -> [Routine] {
        try context.fetch(
            FetchDescriptor<Routine>(
                predicate: #Predicate { $0.isActive },
                sortBy: [SortDescriptor(\.sortIndex), SortDescriptor(\.createdAt)]
            )
        )
    }

    /// A routine on fixed weekdays.
    @discardableResult
    public func create(name: String, weekdays: [Weekday], templates: [WorkoutTemplate]) throws -> Routine {
        let routine = try insert(name: name)
        routine.scheduleType = .weekdays
        routine.weekdays = weekdays
        setTemplates(templates, of: routine)
        return routine
    }

    /// A routine every `intervalDays` days after the last workout, starting from `startDate`.
    @discardableResult
    public func create(
        name: String,
        intervalDays: Int,
        startDate: Date,
        templates: [WorkoutTemplate]
    ) throws -> Routine {
        let routine = try insert(name: name)
        routine.scheduleType = .interval
        routine.intervalDays = max(1, intervalDays)
        routine.startDate = startDate
        setTemplates(templates, of: routine)
        return routine
    }

    /// Replaces the rotation, in this order.
    public func setTemplates(_ templates: [WorkoutTemplate], of routine: Routine) {
        for entry in routine.entries ?? [] {
            context.delete(entry)
        }
        routine.entries = templates.enumerated().map { RoutineEntry(order: $0.offset, template: $0.element) }
    }

    /// Deleting a routine removes its rotation; its sessions stay and keep their title.
    public func delete(_ routine: Routine) {
        context.delete(routine)
    }

    private func insert(name: String) throws -> Routine {
        let routine = Routine(name: name)
        routine.sortIndex = (try all().map(\.sortIndex).max() ?? -1) + 1
        context.insert(routine)
        return routine
    }
}
