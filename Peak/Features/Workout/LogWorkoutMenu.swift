import PeakCore
import PeakDesign
import SwiftData
import SwiftUI

/// "+ Log Workout" under a past day's workouts, on Home and in History (F11-13).
struct LogWorkoutMenu: View {
    let day: Date

    var body: some View {
        Menu {
            LogWorkoutMenuItems(day: day)
        } label: {
            Label("Log Workout", systemImage: "plus")
                .font(.peakRow)
                .foregroundStyle(.peakTextSecondary)
                .frame(maxWidth: .infinity, minHeight: Metrics.minTouchTarget)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// The workouts that can be entered for `day`: first each active routine's next one, saved with its routine so the
/// rotation moves on ("Push Day · Main Routine"); then every workout on its own, which leaves the rotation alone.
struct LogWorkoutMenuItems: View {
    let day: Date

    @Environment(WorkoutLauncher.self) private var launcher
    @Environment(SettingsStore.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.calendar) private var calendar

    @Query(sort: \Routine.sortIndex) private var routines: [Routine]
    @Query(sort: \WorkoutSession.startedAt) private var sessions: [WorkoutSession]
    @Query(filter: #Predicate<WorkoutTemplate> { !$0.isArchived }, sort: \WorkoutTemplate.sortIndex)
    private var templates: [WorkoutTemplate]

    var body: some View {
        let suggestions = DayPlanner(calendar: calendar).logSuggestions(on: day, routines: routines, sessions: sessions)
        if !suggestions.isEmpty {
            Section {
                ForEach(suggestions, id: \.routine.id) { suggestion in
                    Button(suggestion.template.name + " · " + suggestion.routine.name) {
                        log(suggestion.template, routine: suggestion.routine)
                    }
                }
            }
        }
        Section {
            ForEach(templates) { template in
                Button(template.name) { log(template, routine: nil) }
            }
        }
    }

    private func log(_ template: WorkoutTemplate, routine: Routine?) {
        launcher.log(template, routine: routine, on: day, rule: settings.progressionRule, in: modelContext)
    }
}
