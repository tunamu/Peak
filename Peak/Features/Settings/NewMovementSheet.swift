import PeakCore
import PeakDesign
import SwiftData
import SwiftUI

/// S-06 New Movement (not in the design): name, muscle group, equipment, kind and weight increment.
struct NewMovementSheet: View {
    /// Called with the new (or existing, same-named) exercise.
    let onCreate: (Exercise) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsStore.self) private var settings

    @State private var name = ""
    @State private var muscleGroup = MuscleGroup.chest
    @State private var equipment = Equipment.dumbbell
    @State private var kind = ExerciseKind.strength
    @State private var increment = IncrementChoice.small
    @State private var customIncrement = 1.0

    enum IncrementChoice: Hashable {
        case small, large, custom
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Movement Name", text: $name)
                        .font(.peakCardValue)
                        .submitLabel(.done)
                }

                Section {
                    Picker("Type", selection: $kind) {
                        Text("Strength").tag(ExerciseKind.strength)
                        Text("Cardio").tag(ExerciseKind.cardio)
                    }
                    .pickerStyle(.segmented)

                    Picker("Muscle Group", selection: $muscleGroup) {
                        ForEach(MuscleGroup.allCases, id: \.self) { group in
                            Text(group.title).tag(group)
                        }
                    }
                    Picker("Equipment", selection: $equipment) {
                        ForEach(Equipment.allCases, id: \.self) { equipment in
                            Text(equipment.title).tag(equipment)
                        }
                    }
                }

                if kind == .strength {
                    Section {
                        Picker("Weight Increment", selection: $increment) {
                            Text(verbatim: format(steps.small)).tag(IncrementChoice.small)
                            Text(verbatim: format(steps.large)).tag(IncrementChoice.large)
                            Text("Custom").tag(IncrementChoice.custom)
                        }
                        .pickerStyle(.segmented)
                        if increment == .custom {
                            Stepper(value: $customIncrement, in: 0.5...20, step: 0.5) {
                                Text(verbatim: format(customIncrement))
                                    .monospacedDigit()
                            }
                        }
                    } header: {
                        Text("Weight Increment")
                    } footer: {
                        Text("Added to the weight when a set goes above the rep goal.")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("New Movement")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                SheetActionBar(cancel: "Cancel", confirm: "Create", isConfirmEnabled: !trimmedName.isEmpty) {
                    dismiss()
                } onConfirm: {
                    create()
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// The two quick increments in the user's unit: 2.5 / 5 kg or 5 / 10 lb.
    private var steps: (small: Double, large: Double) {
        settings.unitSystem == .metric ? (2.5, 5) : (5, 10)
    }

    private func format(_ value: Double) -> String {
        let unit = settings.unitSystem == .metric ? "kg" : "lb"
        return "\(value.formatted()) \(unit)"
    }

    private func create() {
        let displayValue: Double =
            switch increment {
            case .small: steps.small
            case .large: steps.large
            case .custom: customIncrement
            }
        do {
            let exercise = try ExerciseRepository(context: modelContext).findOrCreate(
                name: trimmedName,
                muscleGroup: kind == .cardio ? .cardio : muscleGroup,
                kind: kind,
                equipment: kind == .cardio ? .other : equipment,
                incrementKg: WeightUnits.kilograms(fromDisplayValue: displayValue, in: settings.unitSystem)
            )
            try modelContext.save()
            onCreate(exercise)
            dismiss()
        } catch {
            assertionFailure("Could not create movement: \(error)")
        }
    }
}

extension MuscleGroup {
    var title: LocalizedStringKey {
        switch self {
        case .chest: "Chest"
        case .back: "Back"
        case .shoulders: "Shoulders"
        case .biceps: "Biceps"
        case .triceps: "Triceps"
        case .legs: "Legs"
        case .core: "Core"
        case .cardio: "Cardio"
        case .other: "Other"
        }
    }
}

extension Equipment {
    var title: LocalizedStringKey {
        switch self {
        case .dumbbell: "Dumbbell"
        case .barbell: "Barbell"
        case .machine: "Machine"
        case .smith: "Smith Machine"
        case .cable: "Cable"
        case .bodyweight: "Bodyweight"
        case .other: "Other"
        }
    }
}
