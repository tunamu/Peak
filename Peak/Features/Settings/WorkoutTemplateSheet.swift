import PeakCore
import PeakDesign
import SwiftData
import SwiftUI

/// S-05 Set Workout: name, the movements it includes (in order, with set counts, each with its own settings behind
/// ⓘ), the workout's own progressive overload (F11-10) and a note.
/// "Delete" archives the template, so past sessions keep it.
struct WorkoutTemplateSheet: View {
    /// `nil` creates a new template.
    let template: WorkoutTemplate?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsStore.self) private var settings
    @Query(filter: #Predicate<Exercise> { !$0.isArchived }, sort: \Exercise.name) private var exercises: [Exercise]

    @State private var name: String
    @State private var note: String
    @State private var chosen: [UUID]
    @State private var sets: [UUID: Int]
    @State private var override: OverloadOverride
    /// The movement whose settings are open.
    @State private var movementSettings: Exercise?
    @State private var isNewMovementShown = false
    @State private var isDeleteConfirmationShown = false

    init(template: WorkoutTemplate?) {
        self.template = template
        let items = template?.orderedItems ?? []
        _name = State(initialValue: template?.name ?? "")
        _note = State(initialValue: template?.note ?? "")
        _override = State(initialValue: template?.overloadOverride ?? OverloadOverride())
        _chosen = State(initialValue: items.compactMap { $0.exercise?.id })
        _sets = State(
            initialValue: Dictionary(
                items.compactMap { item in item.exercise.map { ($0.id, item.targetSets) } },
                uniquingKeysWith: { first, _ in first }
            )
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Workout Name", text: $name)
                        .font(.peakCardValue)
                        .submitLabel(.done)
                } header: {
                    Text("Set Workout Name")
                }

                InclusionSections(
                    chosenTitle: "Movements",
                    othersTitle: "Library",
                    emptyHint: "Tick the movements to include.",
                    items: exercises,
                    chosen: $chosen,
                    title: \.name
                ) { exercise in
                    setStepper(for: exercise)
                    Button("Movement Settings", systemImage: "info.circle") {
                        movementSettings = exercise
                    }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.peakTextSecondary)
                    .buttonStyle(.borderless)
                }

                Section {
                    Button {
                        isNewMovementShown = true
                    } label: {
                        Label("New Movement", systemImage: "plus.circle")
                            .foregroundStyle(.peakTextSecondary)
                    }
                }

                OverloadOverrideSection(
                    override: $override, base: settings.progressionRule,
                    footer: "Off: the workout follows Settings. A movement's own rule (ⓘ) comes first."
                )

                Section {
                    TextField("Add Note", text: $note, axis: .vertical)
                        .lineLimit(1...4)
                }

                if template != nil {
                    Section {
                        Button("Delete Workout", role: .destructive) {
                            isDeleteConfirmationShown = true
                        }
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden)
            .navigationTitle(template == nil ? "New Workout" : "Set Workout")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                SheetActionBar(
                    cancel: "Cancel",
                    confirm: template == nil ? "Create" : "Update",
                    isConfirmEnabled: isValid
                ) {
                    dismiss()
                } onConfirm: {
                    save()
                }
            }
            .sheet(item: $movementSettings) { exercise in
                MovementSettingsSheet(exercise: exercise, template: template)
            }
            .sheet(isPresented: $isNewMovementShown) {
                NewMovementSheet { exercise in
                    if !chosen.contains(exercise.id) {
                        chosen.append(exercise.id)
                    }
                }
            }
            .confirmationDialog(
                "Delete this workout?",
                isPresented: $isDeleteConfirmationShown,
                titleVisibility: .visible
            ) {
                Button("Delete Workout", role: .destructive) {
                    archive()
                }
            } message: {
                Text("Past sessions keep it in their history.")
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isValid: Bool { !trimmedName.isEmpty && !chosen.isEmpty }

    private func setStepper(for exercise: Exercise) -> some View {
        let count = Binding {
            sets[exercise.id] ?? 2
        } set: {
            sets[exercise.id] = $0
        }
        return Stepper(value: count, in: 1...10) {
            Text("\(count.wrappedValue) sets")
                .monospacedDigit()
                .foregroundStyle(.peakTextSecondary)
        }
        .fixedSize()
    }

    private func save() {
        let repository = TemplateRepository(context: modelContext)
        do {
            let target = try template ?? repository.create(name: trimmedName)
            let chosenExercises = chosen.compactMap { id in exercises.first { $0.id == id } }
            target.name = trimmedName
            target.note = note
            target.overloadOverride = override
            target.kind = chosenExercises.allSatisfy { $0.kind == .cardio } ? .cardio : .strength
            repository.setItems(chosenExercises.map { ($0, sets[$0.id] ?? 2) }, of: target)
            try modelContext.save()
            dismiss()
        } catch {
            assertionFailure("Could not save workout: \(error)")
        }
    }

    private func archive() {
        guard let template else { return }
        TemplateRepository(context: modelContext).archive(template)
        try? modelContext.save()
        dismiss()
    }
}
