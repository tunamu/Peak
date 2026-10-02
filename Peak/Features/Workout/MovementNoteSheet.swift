import PeakCore
import PeakDesign
import SwiftData
import SwiftUI

/// F11-12: notes on a movement while logging it. Its setup (kept on the movement, shown every time), last time's note,
/// and a note for this session that becomes part of the movement's history.
struct MovementNoteSheet: View {
    let exercise: SessionExercise

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var setup: String
    @State private var note: String
    @State private var previous: String?

    init(exercise: SessionExercise) {
        self.exercise = exercise
        _setup = State(initialValue: exercise.exercise?.note ?? "")
        _note = State(initialValue: exercise.note)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("How did it go?", text: $note, axis: .vertical)
                        .lineLimit(2...6)
                } header: {
                    Text("This Session")
                }
                if let previous {
                    Section {
                        Text(verbatim: previous)
                            .foregroundStyle(.peakTextSecondary)
                    } header: {
                        Text("Last Time")
                    }
                }
                if exercise.exercise != nil {
                    Section {
                        TextField("Seat height, grip, cable position…", text: $setup, axis: .vertical)
                            .lineLimit(1...4)
                    } header: {
                        Text("Setup")
                    } footer: {
                        Text("Kept on the movement and shown above its sets every time.")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(Text(verbatim: exercise.exerciseName))
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                SheetActionBar(cancel: "Cancel", confirm: "Update") {
                    dismiss()
                } onConfirm: {
                    exercise.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
                    exercise.exercise?.note = setup.trimmingCharacters(in: .whitespacesAndNewlines)
                    try? modelContext.save()
                    dismiss()
                }
            }
            .task {
                previous = try? SessionRepository(context: modelContext).previousNote(before: exercise)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

/// A movement's section header in a workout: its number and name, and the note button (filled when it has notes).
struct MovementHeader: View {
    let index: Int
    let exercise: SessionExercise
    /// `nil` in the read-only view, where notes are only shown.
    var openNotes: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xSmall) {
            Text(verbatim: "\(index + 1)- \(exercise.exerciseName)")
                .font(.peakCardValue)
                .foregroundStyle(.peakTextPrimary)
                .textCase(nil)
            Spacer(minLength: 0)
            if let openNotes {
                Button("Notes", systemImage: hasNotes ? "note.text" : "square.and.pencil", action: openNotes)
                    .labelStyle(.iconOnly)
                    .font(.peakRow)
                    .foregroundStyle(hasNotes ? .peakTextPrimary : .peakTextSecondary)
                    .frame(minWidth: Metrics.minTouchTarget, minHeight: Metrics.minTouchTarget)
                    .contentShape(.rect)
                    .buttonStyle(.plain)
            }
        }
    }

    private var hasNotes: Bool { exercise.hasNotes }
}

extension SessionExercise {
    /// A setup note on the movement or a note on this session.
    var hasNotes: Bool {
        !note.isEmpty || !(exercise?.note ?? "").isEmpty
    }
}

/// The movement's setup and this session's note, above its sets; only added when `hasNotes`.
struct MovementNotesRow: View {
    let exercise: SessionExercise

    var body: some View {
        let setup = exercise.exercise?.note ?? ""
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            if !setup.isEmpty {
                Label {
                    Text(verbatim: setup)
                } icon: {
                    Image(systemName: "pin.fill")
                        .accessibilityLabel(Text("Setup"))
                }
            }
            if !exercise.note.isEmpty {
                Label {
                    Text(verbatim: exercise.note)
                } icon: {
                    Image(systemName: "note.text")
                        .accessibilityLabel(Text("Note"))
                }
            }
        }
        .font(.peakDetail)
        .foregroundStyle(.peakTextSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
