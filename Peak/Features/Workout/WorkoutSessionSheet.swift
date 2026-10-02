import PeakCore
import PeakDesign
import SwiftData
import SwiftUI

/// The running workout: the header (C-10) and one set table per movement (C-09), in a single `List` so reordering,
/// swipe to delete and keyboard avoidance come for free.
///
/// "Complete Movement" folds a movement into a summary row and scrolls to the next open one; tapping the summary opens
/// it again. The bottom bar (C-11) holds the timer with Pause/Resume and Finish Workout (always confirmed); Close and
/// Discard sit in the toolbar. Swiping the sheet down is off so a workout is never closed by accident. A finished
/// workout opens read-only in `CompletedWorkoutSheet`.
///
/// A workout entered after the fact (F11-13, status `logging`) uses the same tables without the timer: the bottom bar
/// holds its time (start and length, changed in `LogTimeSheet`) and Save Workout, and Cancel throws it away.
struct WorkoutSessionSheet: View {
    let session: WorkoutSession
    /// Fixed when the sheet opens: saving turns the session `completed` while the summary is still to come.
    private let isLogging: Bool

    init(session: WorkoutSession) {
        self.session = session
        isLogging = session.status == .logging
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SettingsStore.self) private var settings
    @Environment(HealthConnection.self) private var health
    @State private var isDiscardConfirmationShown = false
    @State private var isFinishConfirmationShown = false
    @State private var isTimeSheetShown = false
    /// The movement whose notes are open (F11-12).
    @State private var notesFor: SessionExercise?
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
                            if exercise.hasNotes {
                                MovementNotesRow(exercise: exercise)
                                    .moveDisabled(true)
                                    .deleteDisabled(true)
                            }
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
                            MovementHeader(index: index, exercise: exercise) {
                                focus = nil
                                notesFor = exercise
                            }
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
                    if isLogging {
                        // Nothing entered yet: gone at once; otherwise asked first.
                        Button("Cancel", systemImage: "xmark") {
                            focus = nil
                            if controller.hasEntries {
                                isDiscardConfirmationShown = true
                            } else {
                                try? controller.discard()
                                dismiss()
                            }
                        }
                    } else {
                        Button("Close", systemImage: "xmark") { dismiss() }
                    }
                }
                if !isLogging {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu("More", systemImage: "ellipsis") {
                            Button("Discard Workout", systemImage: "trash", role: .destructive) {
                                isDiscardConfirmationShown = true
                            }
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
        .sheet(item: $notesFor) { MovementNoteSheet(exercise: $0) }
        .sheet(isPresented: $isTimeSheetShown) {
            LogTimeSheet(start: session.startedAt, duration: session.duration()) { start, duration in
                try? controller.setLogTime(start: start, duration: duration)
            }
        }
        .alert(finishQuestion, isPresented: $isFinishConfirmationShown) {
            Button(isLogging ? "Save Workout" : "Finish Workout") { finish() }
            Button("Cancel", role: .cancel) {}
        } message: {
            if isLogging {
                let day = session.startedAt.formatted(.dateTime.weekday(.wide).day().month(.wide))
                Text("It is added to your history on \(day).")
            } else {
                Text("The workout is saved and the timer stops.")
            }
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
        let previous = (try? SessionRepository(context: modelContext).previousSets(before: exercise)) ?? []
        ForEach(Array(exercise.orderedSets.enumerated()), id: \.element.persistentModelID) { index, set in
            SetRow(
                number: index + 1,
                set: set,
                // Extra sets compare with the last set done, as their targets do.
                previous: previous.indices.contains(index) ? previous[index] : previous.last,
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

}

// MARK: Finishing

extension WorkoutSessionSheet {
    /// The finish pipeline: save the session, show the summary, then write the workout to Health in the background.
    /// Live Activity and widgets join with F9.
    /// "Finish workout?", or with empty sets "3 sets are empty. Finish anyway?"; "Save workout?" when entered after the
    /// fact.
    fileprivate var finishQuestion: Text {
        let empty = controller.emptySetCount
        if isLogging {
            return empty > 0 ? Text("\(empty) sets are empty. Save anyway?") : Text("Save workout?")
        }
        return empty > 0 ? Text("\(empty) sets are empty. Finish anyway?") : Text("Finish workout?")
    }

    fileprivate func finish() {
        let saved = isLogging ? try? controller.saveLog() : try? controller.finish()
        guard saved != nil else { return }
        summary = WorkoutSummary(session: session, rule: settings.progressionRule)
        Task { await saveToHealth() }
    }

    /// Writes the workout to Health once; without access it is skipped, the session stays in Peak either way.
    fileprivate func saveToHealth() async {
        guard health.status == .connected, session.healthKitWorkoutID == nil, let workout = session.healthWorkout
        else { return }
        guard let id = try? await health.service.saveWorkout(workout) else { return }
        session.healthKitWorkoutID = id
        try? modelContext.save()
    }
}

// MARK: Bottom bar

extension WorkoutSessionSheet {
    /// C-11: the timer pill (Pause/Resume) and Finish Workout; when entered after the fact, the time pill and Save.
    fileprivate var bottomBar: some View {
        GlassEffectContainer(spacing: Spacing.medium) {
            HStack(spacing: Spacing.small) {
                if isLogging {
                    logTimeButton
                } else {
                    timerButton
                }
                // Always asked: a stray tap must not end the workout.
                Button {
                    focus = nil
                    isFinishConfirmationShown = true
                } label: {
                    // The short title when the long one would break (large text).
                    ViewThatFits(in: .horizontal) {
                        if isLogging {
                            Label("Save Workout", systemImage: "checkmark").fixedSize()
                            Label("Save", systemImage: "checkmark").fixedSize()
                        } else {
                            Label("Finish Workout", systemImage: "checkmark").fixedSize()
                            Label("Finish", systemImage: "checkmark").fixedSize()
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.peakGlass(.positive))
            }
        }
        // A bar of two controls: capped like a tab bar; a long press shows the large content viewer (F10-02).
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityShowsLargeContentViewer()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("peak.capped.bottomBar")
        .padding(.horizontal, Spacing.screenMargin)
        .padding(.bottom, Spacing.xSmall)
    }

    /// The start and length of a workout entered after the fact; tapping changes them.
    private var logTimeButton: some View {
        Button {
            focus = nil
            isTimeSheetShown = true
        } label: {
            HStack(spacing: Spacing.xSmall) {
                Image(systemName: "clock")
                    .accessibilityHidden(true)
                Text(verbatim: session.startedAt.formatted(date: .omitted, time: .shortened))
                    .monospacedDigit()
            }
        }
        .buttonStyle(.peakGlassPill)
        .accessibilityLabel(Text("Workout Time"))
        .accessibilityValue(Text(verbatim: LogTimeSheet.range(start: session.startedAt, duration: session.duration())))
    }

    /// The running time; tapping pauses or resumes.
    private var timerButton: some View {
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
    }
}
