import PeakDesign
import SwiftUI

/// D-25: a month at a glance on the History page. Days with a workout carry a dot, like the week strip's underline;
/// tapping one narrows the list to it, tapping it again shows the month. The month changes with the arrow buttons,
/// not by swiping, which belongs to the Analysis pages.
struct MonthCalendar: View {
    /// Any day of the month on screen.
    @Binding var month: Date
    @Binding var selection: Date?
    /// Days with a completed workout (start of day).
    let workoutDays: Set<Date>
    let today: Date

    @Environment(\.calendar) private var calendar

    var body: some View {
        VStack(spacing: Spacing.xSmall) {
            header
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    ForEach(weekdaySymbols.indices, id: \.self) { index in
                        Text(verbatim: weekdaySymbols[index])
                            .font(.peakDetail)
                            .foregroundStyle(.peakTextSecondary)
                            .frame(maxWidth: .infinity)
                            .accessibilityHidden(true)
                    }
                }
                ForEach(weeks.indices, id: \.self) { row in
                    GridRow {
                        ForEach(weeks[row].indices, id: \.self) { column in
                            if let day = weeks[row][column] {
                                cell(for: day)
                            } else {
                                Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                            }
                        }
                    }
                }
            }
        }
        .padding(Spacing.small)
        .glassEffect(.regular, in: .rect(cornerRadius: Radius.card))
        // Seven fixed columns cannot grow with the text: capped like the week strip, with the large content viewer
        // (F10-02).
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityIdentifier("peak.capped.monthCalendar")
        .peakHaptic(.selection, trigger: selection)
        .peakHaptic(.selection, trigger: month)
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Button("Previous Month", systemImage: "chevron.left") { move(by: -1) }
                .labelStyle(.iconOnly)
                .frame(minWidth: Metrics.minTouchTarget, minHeight: Metrics.minTouchTarget)
                .contentShape(.rect)
            Spacer(minLength: 0)
            Text(month, format: .dateTime.month(.wide).year())
                .font(.peakCardValue)
                .foregroundStyle(.peakTextPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            Button("Next Month", systemImage: "chevron.right") { move(by: 1) }
                .labelStyle(.iconOnly)
                .frame(minWidth: Metrics.minTouchTarget, minHeight: Metrics.minTouchTarget)
                .contentShape(.rect)
                .disabled(isCurrentMonth)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.peakTextSecondary)
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(month, equalTo: today, toGranularity: .month)
    }

    private func move(by months: Int) {
        guard let next = calendar.date(byAdding: .month, value: months, to: month) else { return }
        withAnimation(.smooth) {
            month = next
            selection = nil
        }
    }

    // MARK: Days

    /// The locale's weekday letters, starting on its first weekday.
    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    /// The month's days in rows of seven, `nil` before the first and after the last.
    private var weeks: [[Date?]] {
        guard let interval = calendar.dateInterval(of: .month, for: month),
            let count = calendar.range(of: .day, in: .month, for: month)?.count
        else { return [] }
        let leading = (calendar.component(.weekday, from: interval.start) - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        cells += (0..<count).map { calendar.date(byAdding: .day, value: $0, to: interval.start) }
        cells += Array(repeating: nil, count: (7 - cells.count % 7) % 7)
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }
    }

    private func cell(for day: Date) -> some View {
        let isSelected = selection.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        let isToday = calendar.isDate(day, inSameDayAs: today)
        let hasWorkout = workoutDays.contains(calendar.startOfDay(for: day))
        let isFuture = calendar.startOfDay(for: day) > calendar.startOfDay(for: today)

        return Button {
            withAnimation(.smooth(duration: 0.2)) {
                selection = isSelected ? nil : day
            }
        } label: {
            VStack(spacing: 3) {
                Text(verbatim: calendar.component(.day, from: day).formatted())
                    .font(isToday ? .peakRow.weight(.bold) : .peakRow)
                    .monospacedDigit()
                    .foregroundStyle(isSelected || isToday || hasWorkout ? .peakTextPrimary : .peakTextSecondary)
                Circle()
                    .fill(isSelected ? .peakTextPrimary : .peakTrendRising)
                    .frame(width: 5, height: 5)
                    .opacity(hasWorkout ? 1 : 0)
            }
            .frame(maxWidth: .infinity, minHeight: Metrics.minTouchTarget)
            .background {
                if isSelected {
                    Capsule().fill(.peakFillControl)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel(Text(day, format: .dateTime.weekday(.wide).day().month(.wide)))
        .accessibilityValue(hasWorkout ? Text("Workout day") : Text(verbatim: ""))
        .accessibilityHint(isToday ? Text("Today") : Text(verbatim: ""))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
