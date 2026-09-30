import PeakCore
import PeakDesign
import SwiftData
import SwiftUI

/// The running workout: the header (C-10) and one set table per movement (C-09), in a single `List` so reordering,
/// swipe to delete and keyboard avoidance come for free.
///
/// "Complete Movement" folds a movement into a summary row and scrolls to the next open one; tapping the summary opens
/// it again. The bottom bar (C-11) holds the timer with Pause/Resume and Finish Workout; Close and Discard sit in the
/// toolbar. Swiping the sheet down is off so a workout is never closed by accident. Walking arrives with F6-05, the
/// finish pipeline and summary with F6-06.
struct WorkoutSessionSheet: View {
    let session: WorkoutSession

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SettingsStore.self) private var settings
    @Environment(HealthConnection.self) private var health
    @State private var isDiscardConfirmationShown = false
    @State private var isFinishConfirmationShown = false
    /// Set once the workout is finished: the sheet then shows the summary (S-11).
    @State private var summary: WorkoutSummary?
    @FocusState private var focus: SetField?

    private var indexedExercises: [(offset: Int, element: SessionExercise)] {
        Array(session.orderedExercises.enumerated())
    }

    private var controller: WorkoutSessionController {
        WorkoutSessionController(session: session, context: modelContext)
    }

    var body: some View {
        if let summary {
            WorkoutSummaryView(summary: summary, unit: settings.unitSystem) { dismiss() }
        } else {
            sessionView
        }
    }

    private var sessionView: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    SessionHeader(session: session)
                        .listRowBackground(Color.clear)
                        .listRowInsets(.init(top: Spacing.xSmall, leading: 0, bottom: Spacing.xSmall, trailing: 0))

                    ForEach(indexedExercises, id: \.element.persistentModelID) { index, exercise in
                        Section {
                            if exercise.isCompleted {
                                CompletedMovementRow(exercise: exercise, unit: settings.unitSystem) {
                                    try? controller.reopenMovement(exercise)
                                }
                            } else {
                                if exercise.isCardio {
                                    segmentRows(of: exercise)
                                } else {
                                    setRows(of: exercise)
                                }
                                completeButton(for: exercise, proxy: proxy)
                            }
                        } header: {
                            Text(verbatim: "\(index + 1)- \(exercise.exerciseName)")
                                .font(.peakCardValue)
                                .foregroundStyle(.peakTextPrimary)
                                .textCase(nil)
                        }
                        .id(exercise.persistentModelID)
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
                        Button("Discard Workout", systemImage: "trash", role: .destructive) {
                            isDiscardConfirmationShown = true
                        }
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    if let next = nextField {
                        Button("Next") { focus = next }
                    }
                    Button("Done") { focus = nil }
                        .fontWeight(.semibold)
                }
            }
            .safeAreaInset(edge: .bottom) { bottomBar }
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled()
        .alert(
            "\(controller.emptySetCount) sets are empty. Finish anyway?",
            isPresented: $isFinishConfirmationShown
        ) {
            Button("Finish Workout") { finish() }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Discard this workout?", isPresented: $isDiscardConfirmationShown, titleVisibility: .visible
        ) {
            Button("Discard Workout", role: .destructive) {
                try? controller.discard()
                dismiss()
            }
        }
        #if DEBUG
            // Screenshot helper: `-PeakFinishWorkout YES` logs three reps over every target and finishes, to show S-11.
            .onAppear {
                guard UserDefaults.standard.bool(forKey: "PeakFinishWorkout") else { return }
                for set in session.orderedExercises.flatMap(\.orderedSets) where set.reps == 0 {
                    try? controller.setReps((set.targetReps ?? 10) + 3, of: set)
                }
                finish()
            }
        #endif
    }

    @ViewBuilder
    private func setRows(of exercise: SessionExercise) -> some View {
        SetColumnsRow(unit: settings.unitSystem)
            .listRowInsets(.init(top: Spacing.small, leading: Spacing.medium, bottom: 0, trailing: Spacing.medium))
            .listRowSeparator(.hidden)
            .moveDisabled(true)
            .deleteDisabled(true)
        ForEach(Array(exercise.orderedSets.enumerated()), id: \.element.persistentModelID) { index, set in
            SetRow(
                number: index + 1,
                set: set,
                unit: settings.unitSystem,
                focus: $focus,
                onWeight: { try? controller.setWeight($0, of: set) },
                onReps: { try? controller.setReps($0, of: set) }
            )
        }
        .onMove { try? controller.moveSets(from: $0, to: $1, in: exercise) }
        .onDelete { try? controller.deleteSets(at: $0, in: exercise) }
        Button {
            try? controller.addSet(to: exercise)
        } label: {
            Label("Add Set", systemImage: "plus")
                .font(.peakRow)
                .foregroundStyle(.peakTextPrimary)
        }
        .moveDisabled(true)
        .deleteDisabled(true)
    }

    private func completeButton(for exercise: SessionExercise, proxy: ScrollViewProxy) -> some View {
        Button {
            focus = nil
            try? controller.completeMovement(exercise)
            if let next = controller.nextOpenMovement(after: exercise) {
                withAnimation {
                    proxy.scrollTo(next.persistentModelID, anchor: .top)
                }
            }
        } label: {
            Label("Complete Movement", systemImage: "checkmark")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.peakGlass)
        .listRowSeparator(.hidden)
        .moveDisabled(true)
        .deleteDisabled(true)
    }

    /// C-12: one row per walking segment (speed, incline, optional duration), Add Segment and swipe to delete.
    @ViewBuilder
    private func segmentRows(of exercise: SessionExercise) -> some View {
        SegmentColumnsRow()
            .listRowInsets(.init(top: Spacing.small, leading: Spacing.medium, bottom: 0, trailing: Spacing.medium))
            .listRowSeparator(.hidden)
            .deleteDisabled(true)
        ForEach(Array(exercise.orderedSegments.enumerated()), id: \.element.persistentModelID) { index, segment in
            SegmentRow(
                number: index + 1,
                segment: segment,
                focus: $focus,
                onSpeed: { try? controller.update(segment, speedKmh: .some($0)) },
                onIncline: { try? controller.update(segment, inclinePercent: .some($0)) },
                onDuration: { try? controller.update(segment, durationMinutes: .some($0)) }
            )
        }
        .onDelete { try? controller.deleteSegments(at: $0, in: exercise) }
        Button {
            try? controller.addSegment(to: exercise)
        } label: {
            Label("Add Segment", systemImage: "plus")
                .font(.peakRow)
                .foregroundStyle(.peakTextPrimary)
        }
        .deleteDisabled(true)
    }

    /// Every editable cell in screen order, movement by movement: weight then reps for sets, speed, incline and
    /// duration for walking segments.
    private var fields: [SetField] {
        session.orderedExercises.filter { !$0.isCompleted }.flatMap { exercise in
            exercise.isCardio
                ? exercise.orderedSegments.flatMap {
                    [
                        SetField.speed($0.persistentModelID), .incline($0.persistentModelID),
                        .duration($0.persistentModelID),
                    ]
                }
                : exercise.orderedSets.flatMap {
                    [SetField.weight($0.persistentModelID), .reps($0.persistentModelID)]
                }
        }
    }

    private var nextField: SetField? {
        guard let focus, let index = fields.firstIndex(of: focus), index + 1 < fields.count else { return nil }
        return fields[index + 1]
    }

    /// C-11: the timer pill (Pause/Resume) and Finish Workout.
    private var bottomBar: some View {
        GlassEffectContainer(spacing: Spacing.medium) {
            HStack(spacing: Spacing.small) {
                Button {
                    if session.status == .paused {
                        try? controller.resume()
                    } else {
                        try? controller.pause()
                    }
                } label: {
                    HStack(spacing: Spacing.xSmall) {
                        SessionClockText(session: session)
                        Image(systemName: session.status == .paused ? "play.fill" : "pause.fill")
                            .accessibilityLabel(session.status == .paused ? "Resume" : "Pause")
                    }
                }
                .buttonStyle(.peakGlassPill)
                Button {
                    focus = nil
                    if controller.emptySetCount > 0 {
                        isFinishConfirmationShown = true
                    } else {
                        finish()
                    }
                } label: {
                    Label("Finish Workout", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.peakGlass(.positive))
            }
        }
        .padding(.horizontal, Spacing.screenMargin)
        .padding(.bottom, Spacing.xSmall)
    }

    /// The finish pipeline: save the session, show the summary, then write the workout to Health in the background.
    /// Live Activity and widgets join with F9.
    private func finish() {
        guard (try? controller.finish()) != nil else { return }
        summary = WorkoutSummary(session: session, rule: settings.progressionRule)
        Task { await saveToHealth() }
    }

    /// Writes the workout to Health once; without access it is skipped, the session stays in Peak either way.
    private func saveToHealth() async {
        guard health.status == .connected, session.healthKitWorkoutID == nil, let workout = session.healthWorkout
        else { return }
        guard let id = try? await health.service.saveWorkout(workout) else { return }
        session.healthKitWorkoutID = id
        try? modelContext.save()
    }
}
