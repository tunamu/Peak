import PeakCore
import PeakDesign
import SwiftUI

/// When a workout entered after the fact (F11-13) started and how long it took, in the form of Set Routine's reminder
/// time. The day stays the one it was entered for; the workout cannot end after now.
struct LogTimeSheet: View {
    let start: Date
    let duration: TimeInterval
    let onSave: (_ start: Date, _ duration: TimeInterval) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.calendar) private var calendar
    @State private var pickedStart: Date
    @State private var pickedMinutes: Int

    init(start: Date, duration: TimeInterval, onSave: @escaping (_ start: Date, _ duration: TimeInterval) -> Void) {
        self.start = start
        self.duration = duration
        self.onSave = onSave
        _pickedStart = State(initialValue: start)
        _pickedMinutes = State(initialValue: max(1, Int((duration / 60).rounded())))
    }

    private var plan: ManualLogPlan {
        ManualLogPlan(start: pickedStart, duration: TimeInterval(pickedMinutes * 60))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Start", selection: $pickedStart, in: dayRange, displayedComponents: .hourAndMinute)
                    // Label and value one above the other, so large text wraps instead of being cut.
                    Stepper(value: $pickedMinutes, in: 1...300, step: Int(ManualLogPlan.step / 60)) {
                        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                            Text("Duration")
                            Text(Self.duration(plan.duration))
                                .monospacedDigit()
                                .foregroundStyle(.peakTextSecondary)
                        }
                    }
                } footer: {
                    // The design's secondary text, which keeps 4.5:1 where the system footer grey does not.
                    Group {
                        if plan.isValid(now: .now) {
                            Text(verbatim: Self.range(start: plan.start, duration: plan.duration))
                                .monospacedDigit()
                        } else {
                            Text("The workout has to be over by now.")
                        }
                    }
                    .foregroundStyle(.peakTextSecondary)
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Workout Time")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                SheetActionBar(cancel: "Cancel", confirm: "Update", isConfirmEnabled: plan.isValid(now: .now)) {
                    dismiss()
                } onConfirm: {
                    onSave(plan.start, plan.duration)
                    dismiss()
                }
            }
        }
        .presentationDetents([.large])
    }

    /// The day the workout was entered for, up to now on today.
    private var dayRange: ClosedRange<Date> {
        let dayStart = calendar.startOfDay(for: start)
        let dayEnd = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: dayStart) ?? dayStart
        return dayStart...max(dayStart, min(dayEnd, .now))
    }

    /// "18:00 – 19:05".
    static func range(start: Date, duration: TimeInterval) -> String {
        let end = start.addingTimeInterval(duration)
        let format = Date.FormatStyle(date: .omitted, time: .shortened)
        return "\(start.formatted(format)) – \(end.formatted(format))"
    }

    /// "1 hr, 5 min" / "1 sa 5 dk".
    static func duration(_ duration: TimeInterval) -> String {
        Duration.seconds(duration).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }
}
