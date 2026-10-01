import PeakCore
import PeakDesign
import SwiftData
import SwiftUI

// The rows and pieces of the workout sheet (WorkoutSessionSheet.swift): header, set and segment tables, the clock.

/// The bottom bar's clock, "00:02:16": ticks every second while running, frozen while paused.
struct SessionClockText: View {
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
struct SessionHeader: View {
    let session: WorkoutSession
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // Name and time side by side; one above the other at accessibility text sizes (F10-02).
        let layout =
            dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.medium))
            : AnyLayout(HStackLayout(alignment: .top, spacing: Spacing.medium))
        layout {
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
            VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: Spacing.xxSmall) {
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
struct CompletedMovementRow: View {
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
    var summary: String? {
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

struct SegmentColumnsRow: View {
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
struct SegmentRow: View {
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
enum SetColumns {
    static let handle: CGFloat = 20
    static let number: CGFloat = 28
    static let value: CGFloat = 64
}

struct SetColumnsRow: View {
    let unit: UnitSystem

    var body: some View {
        HStack(spacing: Spacing.xSmall) {
            Color.clear.frame(width: SetColumns.handle)
            Text("Set").frame(width: SetColumns.number, alignment: .leading)
            Text("Previous").frame(maxWidth: .infinity, alignment: .leading)
            Text(verbatim: unit.weightSymbol).frame(width: SetColumns.value)
            Text("Reps").frame(width: SetColumns.value)
        }
        .font(.peakMeta)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .foregroundStyle(.peakTextTertiary)
        // Read once as the table's header ("Set, Previous, kg, Reps"); each row also names its fields.
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("peak.capped.setColumns")
    }
}

/// C-09 row: handle · set number · reference · weight · reps. Weight starts at the reference weight; reps start empty
/// with the reference reps as placeholder, and entering them completes the set.
struct SetRow: View {
    let number: Int
    let set: SetEntry
    /// The same set last time ("50kg × 9"); the target (one rep more) is the reps field's placeholder.
    let previous: SetPerformance?
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
            TextField(value: weight, format: .number, prompt: Text(verbatim: "0").foregroundStyle(.peakTextSecondary)) {
                Text("Weight")
            }
            .keyboardType(.decimalPad)
            .focused(focus, equals: .weight(set.persistentModelID))
            .accessibilityLabel(Text("Weight"))
            .cell()
            .focusOnTap(focus, .weight(set.persistentModelID))
            // The target reps are information, not a hint: darker than the system's placeholder gray.
            TextField(value: reps, format: .number, prompt: targetPrompt) {
                Text("Reps")
            }
            .keyboardType(.numberPad)
            .focused(focus, equals: .reps(set.persistentModelID))
            .accessibilityLabel(Text("Reps"))
            .cell()
            .focusOnTap(focus, .reps(set.persistentModelID))
        }
        .font(.peakRow.monospacedDigit())
        // Five fixed columns: capped, with the large content viewer beyond (F10-02).
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        // F10-03: one light tap when the set becomes done, not on every digit or when it reopens.
        .peakHaptic(trigger: set.isCompleted) { wasDone, isDone in
            !wasDone && isDone ? .setDone : nil
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Set \(number)"))
        .accessibilityIdentifier("peak.capped.setRow")
    }

    private var targetPrompt: Text {
        Text(verbatim: set.targetReps.map(String.init) ?? "—").foregroundStyle(.peakTextSecondary)
    }

    /// "50kg × 9", or "—" before there is any history.
    private var reference: String {
        guard let previous else { return "—" }
        return "\(format(previous.weightKg))\(unit.weightSymbol) × \(previous.reps)"
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
    /// The text field inside a cell is only as tall as its text; a tap anywhere in the 44 pt cell focuses it.
    func focusOnTap(_ focus: FocusState<SetField?>.Binding, _ field: SetField) -> some View {
        contentShape(.rect)
            .onTapGesture { focus.wrappedValue = field }
    }

    func cell() -> some View {
        multilineTextAlignment(.center)
            // 44 pt: the smallest touch target (F10-02).
            .frame(width: SetColumns.value, height: Metrics.minTouchTarget)
            .background(.peakFillControl, in: .rect(cornerRadius: Radius.control / 2))
    }
}

extension UnitSystem {
    /// "kg" or "lb".
    var weightSymbol: String {
        switch self {
        case .metric: "kg"
        case .imperial: "lb"
        }
    }
}
