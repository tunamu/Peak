import Foundation
import SwiftData

/// Workout templates ("Chest & Biceps") and their exercises.
@MainActor
public final class TemplateRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    /// Templates in the user's order; archived ones only when asked.
    public func all(includingArchived: Bool = false) throws -> [WorkoutTemplate] {
        let descriptor = FetchDescriptor<WorkoutTemplate>(
            predicate: includingArchived ? nil : #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.sortIndex), SortDescriptor(\.createdAt)]
        )
        return try context.fetch(descriptor)
    }

    /// Creates a template at the end of the list.
    @discardableResult
    public func create(name: String, kind: ExerciseKind = .strength, note: String = "") throws -> WorkoutTemplate {
        let template = WorkoutTemplate(name: name)
        template.kind = kind
        template.note = note
        template.sortIndex = (try all(includingArchived: true).map(\.sortIndex).max() ?? -1) + 1
        context.insert(template)
        return template
    }

    /// Replaces the template's exercises, in this order.
    public func setItems(_ items: [(exercise: Exercise, targetSets: Int)], of template: WorkoutTemplate) {
        for item in template.items ?? [] {
            context.delete(item)
        }
        template.items = items.enumerated().map { index, item in
            TemplateItem(order: index, targetSets: max(1, item.targetSets), exercise: item.exercise)
        }
    }

    /// Moves templates to the given order (drag to reorder in Settings).
    public func reorder(_ templates: [WorkoutTemplate]) {
        for (index, template) in templates.enumerated() {
            template.sortIndex = index
        }
    }

    /// "Delete" in the UI: hidden from lists, but past sessions and routines keep pointing at it.
    public func archive(_ template: WorkoutTemplate) {
        template.isArchived = true
    }
}
