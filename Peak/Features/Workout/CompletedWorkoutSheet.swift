import PeakCore
import PeakDesign
import SwiftData
import SwiftUI

/// A finished workout, read-only: opened by tapping a completed card on Home, today or any past day. The same
/// header and tables as the running workout, without the timer, the bottom bar or editing. It can be deleted, also
/// from Apple Health (F11-13), for a workout entered by mistake.
struct CompletedWorkoutSheet: View {
    let session: WorkoutSession

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SettingsStore.self) private var settings
    @Environment(HealthConnection.self) private var health
    @State private var isDeleteConfirmationShown = false
    /// Set before deleting, so the sheet stops reading the session while it closes.
    @State private var isDeleted = false

    private var indexedExercises: [(offset: Int, element: SessionExercise)] {
        Array(session.orderedExercises.enumerated())
    }

    var body: some View {
        if isDeleted {
            Color.clear
        } else {
            content
        }
    }

    private var content: some View {
        NavigationStack {
            List {
                SessionHeader(session: session)
                    .listRowBackground(Color.clear)
                    .listRowInsets(.init(top: Spacing.xSmall, leading: 0, bottom: Spacing.xSmall, trailing: 0))

                ForEach(indexedExercises, id: \.element.persistentModelID) { index, exercise in
                    Section {
                        if exercise.hasNotes {
                            MovementNotesRow(exercise: exercise)
                        }
                        if exercise.isCardio {
                            segmentRows(of: exercise)
                        } else {
                            setRows(of: exercise)
                        }
                    } header: {
                        MovementHeader(index: index, exercise: exercise)
                    }
                }
            }
            .listSectionSpacing(Spacing.medium)
            .contentMargins(.top, 0, for: .scrollContent)
            .environment(\.defaultMinListRowHeight, 0)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("More", systemImage: "ellipsis") {
                        Button("Delete Workout", systemImage: "trash", role: .destructive) {
                            isDeleteConfirmationShown = true
                        }
                    }
                }
            }
            .confirmationDialog(
                "Delete this workout?", isPresented: $isDeleteConfirmationShown, titleVisibility: .visible
            ) {
                Button("Delete Workout", role: .destructive) { delete() }
            } message: {
                Text("It is removed from your history and from Apple Health.")
            }
        }
        .presentationDetents([.large])
    }

    /// Deletes the session, then its Health workout in the background; Health failing does not keep it in Peak.
    private func delete() {
        let healthID = session.healthKitWorkoutID
        isDeleted = true
        SessionRepository(context: modelContext).discard(session)
        try? modelContext.save()
        dismiss()
        if let healthID {
            let service = health.service
            Task { try? await service.deleteWorkout(id: healthID) }
        }
    }

    @ViewBuilder
    private func setRows(of exercise: SessionExercise) -> some View {
        let sets = exercise.orderedSets
        if sets.isEmpty {
            Text("No sets logged")
                .font(.peakRow)
                .foregroundStyle(.peakTextTertiary)
        } else {
            SetColumnsRow(unit: settings.unitSystem)
                .listRowInsets(.init(top: Spacing.small, leading: Spacing.medium, bottom: 0, trailing: Spacing.medium))
                .listRowSeparator(.hidden)
            let previous = (try? SessionRepository(context: modelContext).previousSets(before: exercise)) ?? []
            ForEach(Array(sets.enumerated()), id: \.element.persistentModelID) { index, set in
                LoggedSetRow(
                    number: index + 1, set: set, unit: settings.unitSystem,
                    previous: previous.indices.contains(index) ? previous[index] : previous.last)
            }
        }
    }

    @ViewBuilder
    private func segmentRows(of exercise: SessionExercise) -> some View {
        SegmentColumnsRow()
            .listRowInsets(.init(top: Spacing.small, leading: Spacing.medium, bottom: 0, trailing: Spacing.medium))
            .listRowSeparator(.hidden)
        ForEach(Array(exercise.orderedSegments.enumerated()), id: \.element.persistentModelID) { index, segment in
            LoggedSegmentRow(number: index + 1, segment: segment)
        }
    }
}

/// A set as it was logged: the same columns as the running table (C-09), as text.
private struct LoggedSetRow: View {
    let number: Int
    let set: SetEntry
    let unit: UnitSystem
    /// The same set the time before this workout.
    let previous: SetPerformance?

    var body: some View {
        HStack(spacing: Spacing.xSmall) {
            Color.clear.frame(width: SetColumns.handle)
            Text(number, format: .number)
                .foregroundStyle(set.isCompleted ? .peakTintPositive : .peakTextSecondary)
                .frame(width: SetColumns.number, alignment: .leading)
            Text(verbatim: reference)
                .foregroundStyle(.peakTextTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(verbatim: set.reps > 0 || set.weightKg > 0 ? format(set.weightKg) : "—")
                .foregroundStyle(.peakTextPrimary)
                .frame(width: SetColumns.value)
            Text(verbatim: set.reps > 0 ? String(set.reps) : "—")
                .foregroundStyle(.peakTextPrimary)
                .frame(width: SetColumns.value)
        }
        .font(.peakRow.monospacedDigit())
        .frame(minHeight: 36)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Set \(number)"))
        .accessibilityValue(Text(verbatim: "\(format(set.weightKg)) \(unit.weightSymbol) × \(set.reps)"))
    }

    /// The same set the time before, "50kg × 9", or "—".
    private var reference: String {
        guard let previous else { return "—" }
        return "\(format(previous.weightKg))\(unit.weightSymbol) × \(previous.reps)"
    }

    private func format(_ weightKg: Double) -> String {
        WeightUnits.displayValue(kg: weightKg, in: unit).formatted(.number.precision(.fractionLength(0...2)))
    }
}

/// A walking segment as it was logged: speed, incline and minutes, "—" where empty.
private struct LoggedSegmentRow: View {
    let number: Int
    let segment: CardioSegment

    var body: some View {
        HStack(spacing: Spacing.xSmall) {
            Text(number, format: .number)
                .foregroundStyle(.peakTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            value(segment.speedKmh)
            value(segment.inclinePercent)
            value(segment.durationSec.map { Double($0) / 60 })
        }
        .font(.peakRow.monospacedDigit())
        .frame(minHeight: 36)
        .accessibilityElement(children: .combine)
    }

    private func value(_ number: Double?) -> some View {
        Text(verbatim: number.map { $0.formatted(.number.precision(.fractionLength(0...1))) } ?? "—")
            .foregroundStyle(.peakTextPrimary)
            .frame(width: SetColumns.value)
    }
}
