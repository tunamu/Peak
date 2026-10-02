import PeakCore
import PeakDesign
import SwiftUI

/// F11-06: every completed workout, a month at a time under the calendar (D-25). A day picked on the calendar narrows
/// the list to it. Each row opens the workout read-only, as on Home. A picked day up to today can have a workout
/// entered after the fact (F11-13).
struct HistoryPage: View {
    /// Completed sessions, newest first.
    let sessions: [WorkoutSession]
    let open: (WorkoutSession) -> Void

    @Environment(\.calendar) private var calendar
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var month: Date?
    @State private var selection: Date?

    var body: some View {
        let today = Date.now
        let month = month ?? sessions.first?.startedAt ?? today
        let shown = shownSessions(month: month)
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                MonthCalendar(
                    month: Binding(get: { month }, set: { self.month = $0 }),
                    selection: $selection,
                    workoutDays: Set(sessions.map { calendar.startOfDay(for: $0.startedAt) }),
                    today: today
                )
                VStack(alignment: .leading, spacing: Spacing.small) {
                    listHeader(month: month, count: shown.count)
                    if shown.isEmpty {
                        Text(selection == nil ? "No workouts this month." : "No workout on this day.")
                            .font(.peakRow)
                            .foregroundStyle(.peakTextSecondary)
                            .padding(.horizontal, Spacing.xSmall)
                    } else {
                        GlassEffectContainer(spacing: Spacing.medium) {
                            VStack(spacing: Spacing.medium) {
                                ForEach(shown) { session in
                                    card(for: session)
                                }
                            }
                        }
                    }
                    if let selection, calendar.startOfDay(for: selection) <= calendar.startOfDay(for: today) {
                        LogWorkoutMenu(day: selection)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.bottom, Spacing.medium)
        }
    }

    private func shownSessions(month: Date) -> [WorkoutSession] {
        if let selection {
            return sessions.filter { calendar.isDate($0.startedAt, inSameDayAs: selection) }
        }
        return sessions.filter { calendar.isDate($0.startedAt, equalTo: month, toGranularity: .month) }
    }

    private func listHeader(month: Date, count: Int) -> some View {
        // Side by side; one above the other at accessibility text sizes, so words are not broken (F10-02).
        let layout =
            dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.xxSmall))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Spacing.xSmall))
        return layout {
            Group {
                if let selection {
                    Text(selection, format: .dateTime.weekday(.wide).day().month(.wide))
                } else {
                    Text(month, format: .dateTime.month(.wide).year())
                }
            }
            .font(.peakSectionTitle)
            .foregroundStyle(.peakTextPrimary)
            .accessibilityAddTraits(.isHeader)
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: 0)
            }
            if selection != nil {
                Button("Show Month") {
                    withAnimation(.smooth(duration: 0.2)) { selection = nil }
                }
                .font(.peakRow)
                .foregroundStyle(.peakTextSecondary)
                .frame(minHeight: Metrics.minTouchTarget)
                .contentShape(.rect)
                .buttonStyle(.plain)
            } else if count > 0 {
                Text("\(count) Workouts")
                    .font(.peakRow)
                    .foregroundStyle(.peakTextSecondary)
            }
        }
    }

    /// The same card as a finished workout on Home (C-03): its date, name, time and movements done. Tapping opens it.
    private func card(for session: WorkoutSession) -> some View {
        TodayWorkoutCard(
            label: Text(session.startedAt, format: .dateTime.weekday(.wide).day().month(.wide)),
            state: .completed(
                name: session.title, duration: session.duration(), movementsDone: session.completedMovementCount,
                movements: session.orderedExercises.count),
            action: nil,
            open: { open(session) }
        )
    }
}
