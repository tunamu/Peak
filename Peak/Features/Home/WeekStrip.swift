import PeakCore
import PeakDesign
import SwiftUI

/// C-02: seven days in one glass capsule, like the tab bar. Pages start the day before today, so today is always the
/// second day (as in the design). The selected day sits in a pill that can be dragged along the page, like the tab
/// bar's; swiping anywhere else pages seven days back or ahead. Days with a workout are underlined.
struct WeekStrip: View {
    @Binding var selection: Date
    let today: Date
    /// Days with a completed or planned workout (start of day): underlined, and read out by VoiceOver.
    let workoutDays: Set<Date>

    @Environment(\.calendar) private var calendar
    /// The first day of the page on screen; the scroll view pages through these.
    @State private var visibleWeek: Date?
    @State private var isDragging = false
    /// Only a swipe by the user moves the selection to another week, not the scroll view settling on its own.
    @State private var isUserScrolling = false
    @State private var pageWidth: CGFloat = 0

    /// Space between the capsule's edge and the pill.
    private let inset: CGFloat = 4

    init(selection: Binding<Date>, today: Date, workoutDays: Set<Date>) {
        _selection = selection
        self.today = today
        self.workoutDays = workoutDays
        // Start on the selected week; set later, the scroll view would first report the oldest week.
        _visibleWeek = State(
            initialValue: Self.pageStart(of: selection.wrappedValue, today: today, calendar: .current))
    }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(weeks, id: \.self) { weekStart in
                    page(for: weekStart)
                        .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $visibleWeek)
        .clipShape(.capsule)
        .glassEffect(.regular, in: .capsule)
        .onGeometryChange(for: CGFloat.self) {
            $0.size.width
        } action: {
            pageWidth = $0
        }
        .onScrollPhaseChange { _, phase in
            isUserScrolling = phase == .interacting || phase == .decelerating
        }
        // A day picked elsewhere (double-tapping the title) scrolls to its week.
        .onChange(of: selection) {
            let week = weekStart(of: selection)
            if visibleWeek != week {
                withAnimation(.smooth) { visibleWeek = week }
            }
        }
        // Paging keeps the place in the page: the second day stays the second day.
        .onChange(of: visibleWeek) {
            guard isUserScrolling, let visibleWeek, weekStart(of: selection) != visibleWeek else { return }
            let offset = calendar.dateComponents([.day], from: weekStart(of: selection), to: selection).day ?? 0
            if let day = calendar.date(byAdding: .day, value: offset, to: visibleWeek) {
                selection = day
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }

    // MARK: Weeks

    /// Two years back and one year ahead of today's page.
    private var weeks: [Date] {
        let current = weekStart(of: today)
        return (-104...52).compactMap { calendar.date(byAdding: .day, value: $0 * 7, to: current) }
    }

    private func weekStart(of day: Date) -> Date {
        Self.pageStart(of: day, today: today, calendar: calendar)
    }

    /// The first day of the page holding `day`. Pages are seven days long and today's page starts yesterday.
    static func pageStart(of day: Date, today: Date, calendar: Calendar) -> Date {
        let todayStart = calendar.startOfDay(for: today)
        let anchor = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
        let distance = calendar.dateComponents([.day], from: anchor, to: calendar.startOfDay(for: day)).day ?? 0
        let pages = Int((Double(distance) / 7).rounded(.down))
        return calendar.date(byAdding: .day, value: pages * 7, to: anchor) ?? anchor
    }

    /// The page holding `day` and the pages on each side, for the workout underlines.
    static func days(around day: Date, today: Date, calendar: Calendar) -> [Date] {
        let start = pageStart(of: day, today: today, calendar: calendar)
        return (-7..<14).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private func days(from weekStart: Date) -> [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    /// Width of one day inside the capsule.
    private var slot: CGFloat {
        max(0, pageWidth - 2 * inset) / 7
    }

    // MARK: Page

    private func page(for weekStart: Date) -> some View {
        let days = days(from: weekStart)
        let selectedIndex = days.firstIndex { calendar.isDate($0, inSameDayAs: selection) }

        return HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                chip(for: day)
            }
        }
        .padding(inset)
        .background(alignment: .leading) {
            // The pill, like the tab bar's selected tab. It slides from day to day and swells while dragged.
            if let selectedIndex {
                Capsule()
                    .fill(.peakFillControl)
                    .frame(width: slot)
                    .padding(.vertical, inset)
                    .scaleEffect(isDragging ? 1.1 : 1)
                    .offset(x: inset + CGFloat(selectedIndex) * slot)
                    .animation(.smooth(duration: 0.25), value: selectedIndex)
                    .animation(.spring(duration: 0.3, bounce: 0.4), value: isDragging)
            }
        }
        .overlay(alignment: .leading) {
            // Grabbing the pill drags it along the week; this sits over the pill only, so swipes elsewhere page.
            if let selectedIndex {
                Capsule()
                    .fill(.clear)
                    .contentShape(.capsule)
                    .frame(width: slot)
                    .offset(x: inset + CGFloat(selectedIndex) * slot)
                    .highPriorityGesture(dragPill(across: days))
                    .accessibilityHidden(true)
            }
        }
        .coordinateSpace(.named(Self.pageSpace))
    }

    private static let pageSpace = "WeekStrip.page"

    private func dragPill(across days: [Date]) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.pageSpace))
            .onChanged { value in
                isDragging = true
                guard slot > 0 else { return }
                let index = min(max(Int((value.location.x - inset) / slot), 0), days.count - 1)
                if !calendar.isDate(days[index], inSameDayAs: selection) {
                    selection = days[index]
                }
            }
            .onEnded { _ in
                isDragging = false
            }
    }

    private func chip(for day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selection)
        let isToday = calendar.isDate(day, inSameDayAs: today)
        let weekday = calendar.component(.weekday, from: day) - 1
        let hasWorkout = workoutDays.contains(calendar.startOfDay(for: day))

        return Button {
            selection = day
        } label: {
            VStack(spacing: 2) {
                Text(verbatim: calendar.veryShortStandaloneWeekdaySymbols[weekday])
                    .font(.peakDetail)
                    .foregroundStyle(isSelected ? .peakTextPrimary : .peakTextSecondary)
                Text(verbatim: calendar.component(.day, from: day).formatted())
                    .font(.peakCardValue)
                    .monospacedDigit()
                    .foregroundStyle(isSelected || isToday ? .peakTextPrimary : .peakTextSecondary)
                // The underline of a workout day.
                Capsule()
                    .fill(isSelected || isToday ? .peakTextPrimary : .peakTextSecondary)
                    .frame(width: 14, height: 3)
                    .opacity(hasWorkout ? 1 : 0)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, Spacing.small)
            .padding(.bottom, Spacing.xSmall)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(day, format: .dateTime.weekday(.wide).day().month(.wide)))
        .accessibilityValue(
            hasWorkout ? Text("Workout day") : Text(verbatim: "")
        )
        .accessibilityHint(isToday ? Text("Today") : Text(verbatim: ""))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
