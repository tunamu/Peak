import PeakCore
import PeakDesign
import SwiftUI

/// C-02: the seven days of the selected week. Tap a day to show it; swipe sideways for the previous or next week.
/// The week starts on the locale's first weekday.
struct WeekStrip: View {
    @Binding var selection: Date
    let today: Date
    /// Days with a completed or planned workout (start of day), for VoiceOver.
    let workoutDays: Set<Date>

    @Environment(\.calendar) private var calendar
    @ScaledMetric(relativeTo: .headline) private var chipSize = Metrics.dayChip

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 0) {
                ForEach(week, id: \.self) { day in
                    chip(for: day)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .contentShape(.rect)
        .gesture(
            DragGesture(minimumDistance: 24).onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                if value.translation.width < -40 {
                    moveWeek(by: 1)
                } else if value.translation.width > 40 {
                    moveWeek(by: -1)
                }
            }
        )
        .sensoryFeedback(.selection, trigger: selection)
    }

    private var week: [Date] {
        RoutineScheduler(calendar: calendar).week(containing: selection)
    }

    private func chip(for day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selection)
        let isToday = calendar.isDate(day, inSameDayAs: today)
        let weekday = calendar.component(.weekday, from: day) - 1

        return Button {
            withAnimation(.smooth) { selection = day }
        } label: {
            VStack(spacing: 2) {
                Text(verbatim: calendar.veryShortStandaloneWeekdaySymbols[weekday])
                    .font(.peakCardLabel)
                    .foregroundStyle(isSelected ? .peakTextPrimary : .peakTextSecondary)
                Text(verbatim: calendar.component(.day, from: day).formatted())
                    .font(.peakCardValue)
                    .monospacedDigit()
                    .foregroundStyle(isSelected || isToday ? .peakTextPrimary : .peakTextSecondary)
                    .frame(width: chipSize, height: chipSize)
                    // Glass on the number itself keeps the number above the glass. Only the selected day has it.
                    .glassEffect(isSelected ? .regular : .identity, in: .circle)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(day, format: .dateTime.weekday(.wide).day().month(.wide)))
        .accessibilityValue(
            workoutDays.contains(calendar.startOfDay(for: day)) ? Text("Workout day") : Text(verbatim: "")
        )
        .accessibilityHint(isToday ? Text("Today") : Text(verbatim: ""))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func moveWeek(by weeks: Int) {
        guard let day = calendar.date(byAdding: .weekOfYear, value: weeks, to: selection) else { return }
        withAnimation(.smooth) { selection = day }
    }
}

#if DEBUG
    #Preview {
        @Previewable @State var selection = Date.now
        WeekStrip(selection: $selection, today: .now, workoutDays: [])
            .padding()
            .background(.peakCanvas)
    }
#endif
