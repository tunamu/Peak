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

                    ForEach(Array(session.orderedExercises.enumerated()), id: \.element.persistentModelID) {
                        index, exercise in
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

/// The bottom bar's clock, "00:02:16": ticks every second while running, frozen while paused.
private struct SessionClockText: View {
    let session: WorkoutSession

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let seconds = session.duration(now: context.date).rounded(.down)
            Text(verbatim: Duration.seconds(seconds).formatted(.time(pattern: .hourMinuteSecond(padHourToLength: 2))))
                .monospacedDigit()
        }
    }
}

/// A focusable cell of a set or segment row.
enum SetField: Hashable {
    case weight(PersistentIdentifier)
    case reps(PersistentIdentifier)
    case speed(PersistentIdentifier)
    case incline(PersistentIdentifier)
    case duration(PersistentIdentifier)
}

/// C-10: date, name and size on the left; time and progress on the right.
private struct SessionHeader: View {
    let session: WorkoutSession

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.medium) {
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                Text(session.startedAt, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.peakDetail)
                    .foregroundStyle(.peakTextSecondary)
                Text(verbatim: session.title)
                    .font(.peakScreenTitle.weight(.semibold))
                    .foregroundStyle(.peakTextPrimary)
                Text(verbatim: summary)
                    .font(.peakRow)
                    .foregroundStyle(.peakTextSecondary)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: Spacing.xxSmall) {
                Text("Time")
                    .font(.peakDetail)
                    .foregroundStyle(.peakTextSecondary)
                SessionTimerText(session: session)
                    .font(.peakSectionTitle.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.peakTextPrimary)
                Text("\(session.completion.formatted(.percent.precision(.fractionLength(0)))) Completed")
                    .font(.peakRow)
                    .foregroundStyle(.peakTextSecondary)
            }
        }
        .padding(.horizontal, Spacing.xxSmall)
    }

    /// "5 Movements · 13 Sets"; a walk alone has no sets.
    private var summary: String {
        var parts = [String(localized: "\(session.orderedExercises.count) Movements")]
        if session.setCount > 0 {
            parts.append(String(localized: "\(session.setCount) Sets"))
        }
        return parts.joined(separator: " · ")
    }
}

/// A completed movement folded into one row: "✓ 52.5 × 10 · 50 × 8". Tapping opens it again.
private struct CompletedMovementRow: View {
    let exercise: SessionExercise
    let unit: UnitSystem
    let reopen: () -> Void

    var body: some View {
        Button(action: reopen) {
            HStack(spacing: Spacing.xSmall) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.peakTintPositive)
                    .accessibilityHidden(true)
                Text(verbatim: summary)
                    .foregroundStyle(.peakTextSecondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.down")
                    .font(.peakDetail)
                    .foregroundStyle(.peakTextTertiary)
                    .accessibilityHidden(true)
            }
            .font(.peakRow.monospacedDigit())
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Completed: \(summary)"))
        .accessibilityHint(Text("Opens the movement again"))
    }

    /// The done sets, "52.5 × 10 · 50 × 8", or the walk's segments, "5.5 km/h 12% 30 min · 4 km/h 8%"; a movement with
    /// nothing logged reads "Completed".
    private var summary: String {
        let done =
            exercise.isCardio
            ? exercise.orderedSegments.compactMap(\.summary)
            : exercise.orderedSets.filter { $0.reps > 0 }.map {
                let weight = WeightUnits.displayValue(kg: $0.weightKg, in: unit)
                    .formatted(.number.precision(.fractionLength(0...2)))
                return "\(weight) × \($0.reps)"
            }
        return done.isEmpty ? String(localized: "Completed") : done.joined(separator: " · ")
    }
}

extension CardioSegment {
    /// "5.5 km/h 12% 30 min", leaving out what is empty; `nil` when nothing was entered.
    fileprivate var summary: String? {
        let number = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0...1))
        var parts: [String] = []
        if let speedKmh { parts.append("\(speedKmh.formatted(number)) km/h") }
        if let inclinePercent {
            parts.append((inclinePercent / 100).formatted(.percent.precision(.fractionLength(0...1))))
        }
        if let durationSec { parts.append(String(localized: "\(durationSec / 60) min")) }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}

private struct SegmentColumnsRow: View {
    var body: some View {
        HStack(spacing: Spacing.xSmall) {
            Text("Segment").frame(maxWidth: .infinity, alignment: .leading)
            Text(verbatim: "km/h").frame(width: SetColumns.value)
            Text(verbatim: "%").frame(width: SetColumns.value)
            Text("min").frame(width: SetColumns.value)
        }
        .font(.peakMeta)
        .foregroundStyle(.peakTextTertiary)
        .accessibilityHidden(true)
    }
}

/// C-12 row: segment number · speed · incline · duration. An empty duration means "the rest of the session".
private struct SegmentRow: View {
    let number: Int
    let segment: CardioSegment
    var focus: FocusState<SetField?>.Binding
    let onSpeed: (Double?) -> Void
    let onIncline: (Double?) -> Void
    let onDuration: (Int?) -> Void

    var body: some View {
        HStack(spacing: Spacing.xSmall) {
            Text(number, format: .number)
                .foregroundStyle(.peakTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField(value: speed, format: .number, prompt: Text(verbatim: "—")) {
                Text("Speed")
            }
            .keyboardType(.decimalPad)
            .focused(focus, equals: .speed(segment.persistentModelID))
            .cell()
            TextField(value: incline, format: .number, prompt: Text(verbatim: "—")) {
                Text("Incline")
            }
            .keyboardType(.decimalPad)
            .focused(focus, equals: .incline(segment.persistentModelID))
            .cell()
            TextField(value: duration, format: .number, prompt: Text(verbatim: "—")) {
                Text("Duration")
            }
            .keyboardType(.numberPad)
            .focused(focus, equals: .duration(segment.persistentModelID))
            .cell()
        }
        .font(.peakRow.monospacedDigit())
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Segment \(number)"))
    }

    private var speed: Binding<Double?> {
        Binding {
            segment.speedKmh
        } set: {
            onSpeed($0)
        }
    }

    private var incline: Binding<Double?> {
        Binding {
            segment.inclinePercent
        } set: {
            onIncline($0)
        }
    }

    private var duration: Binding<Int?> {
        Binding {
            segment.durationSec.map { $0 / 60 }
        } set: {
            onDuration($0)
        }
    }
}

/// Fixed column widths, shared by the column titles and the rows so they line up.
private enum SetColumns {
    static let handle: CGFloat = 20
    static let number: CGFloat = 28
    static let value: CGFloat = 64
}

private struct SetColumnsRow: View {
    let unit: UnitSystem

    var body: some View {
        HStack(spacing: Spacing.xSmall) {
            Color.clear.frame(width: SetColumns.handle)
            Text("Set").frame(width: SetColumns.number, alignment: .leading)
            Text("Reference").frame(maxWidth: .infinity, alignment: .leading)
            Text(verbatim: unit.weightSymbol).frame(width: SetColumns.value)
            Text("Reps").frame(width: SetColumns.value)
        }
        .font(.peakMeta)
        .foregroundStyle(.peakTextTertiary)
        .accessibilityHidden(true)
    }
}

/// C-09 row: handle · set number · reference · weight · reps. Weight starts at the reference weight; reps start empty
/// with the reference reps as placeholder, and entering them completes the set.
private struct SetRow: View {
    let number: Int
    let set: SetEntry
    let unit: UnitSystem
    var focus: FocusState<SetField?>.Binding
    let onWeight: (Double) -> Void
    let onReps: (Int) -> Void

    var body: some View {
        HStack(spacing: Spacing.xSmall) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.peakTextTertiary)
                .frame(width: SetColumns.handle)
                .accessibilityHidden(true)
            Text(number, format: .number)
                .foregroundStyle(set.isCompleted ? .peakTintPositive : .peakTextSecondary)
                .frame(width: SetColumns.number, alignment: .leading)
            Text(verbatim: reference)
                .foregroundStyle(.peakTextTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField(value: weight, format: .number, prompt: Text(verbatim: "0")) {
                Text("Weight")
            }
            .keyboardType(.decimalPad)
            .focused(focus, equals: .weight(set.persistentModelID))
            .cell()
            TextField(value: reps, format: .number, prompt: Text(verbatim: set.targetReps.map(String.init) ?? "—")) {
                Text("Reps")
            }
            .keyboardType(.numberPad)
            .focused(focus, equals: .reps(set.persistentModelID))
            .cell()
        }
        .font(.peakRow.monospacedDigit())
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Set \(number)"))
    }

    /// "27.5kg × 6", or "—" before there is any history.
    private var reference: String {
        guard let weightKg = set.targetWeightKg, let reps = set.targetReps else { return "—" }
        return "\(format(weightKg))\(unit.weightSymbol) × \(reps)"
    }

    private var weight: Binding<Double?> {
        Binding {
            set.weightKg > 0 || set.isCompleted ? WeightUnits.displayValue(kg: set.weightKg, in: unit) : nil
        } set: {
            onWeight(WeightUnits.kilograms(fromDisplayValue: $0 ?? 0, in: unit))
        }
    }

    private var reps: Binding<Int?> {
        Binding {
            set.reps > 0 ? set.reps : nil
        } set: {
            onReps($0 ?? 0)
        }
    }

    private func format(_ weightKg: Double) -> String {
        WeightUnits.displayValue(kg: weightKg, in: unit).formatted(.number.precision(.fractionLength(0...2)))
    }
}

extension View {
    /// An editable number cell of the set table.
    fileprivate func cell() -> some View {
        multilineTextAlignment(.center)
            .frame(width: SetColumns.value, height: 36)
            .background(.peakFillControl, in: .rect(cornerRadius: Radius.control / 2))
    }
}

extension UnitSystem {
    /// "kg" or "lb".
    fileprivate var weightSymbol: String {
        switch self {
        case .metric: "kg"
        case .imperial: "lb"
        }
    }
}
