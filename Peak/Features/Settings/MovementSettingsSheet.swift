import PeakCore
import PeakDesign
import SwiftData
import SwiftUI

/// A movement's own settings: how it is set up (F11-12) and its own progressive overload (F11-10). Opened from Set
/// Workout (the ⓘ beside a movement) and from the movement's chart in Analysis.
struct MovementSettingsSheet: View {
    let exercise: Exercise
    /// The workout it is opened from, whose own rule a movement without one follows.
    var template: WorkoutTemplate?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsStore.self) private var settings

    @State private var note: String
    @State private var override: OverloadOverride

    init(exercise: Exercise, template: WorkoutTemplate? = nil) {
        self.exercise = exercise
        self.template = template
        _note = State(initialValue: exercise.note)
        _override = State(initialValue: exercise.overloadOverride)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Seat height, grip, cable position…", text: $note, axis: .vertical)
                        .lineLimit(2...6)
                } header: {
                    Text("Setup")
                } footer: {
                    Text("Shown above the movement's sets while you log it.")
                }

                if exercise.kind == .strength {
                    OverloadOverrideSection(
                        override: $override,
                        base: settings.progressionRule.applying(template?.overloadOverride),
                        footer: template == nil
                            ? "Off: the movement follows its workout's rule, or Settings."
                            : "Off: the movement follows this workout's rule, or Settings."
                    )
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(Text(verbatim: exercise.name))
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                SheetActionBar(cancel: "Cancel", confirm: "Update") {
                    dismiss()
                } onConfirm: {
                    exercise.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
                    exercise.overloadOverride = override
                    try? modelContext.save()
                    dismiss()
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
