import PeakCore
import PeakDesign
import SwiftData
import SwiftUI

/// Home tab (design: `Ana Ekran`): the week, the selected day's workouts, and the dashboard (steps, energy, water).
/// Picking another day moves every card to that day: done workouts in the past, planned ones ahead.
struct HomeView: View {
    /// Switches to the Settings tab, where routines are set up.
    let openSettings: () -> Void

    @Environment(SettingsStore.self) private var settings
    @Environment(HealthConnection.self) private var health
    @Environment(WorkoutLauncher.self) private var launcher
    @Environment(\.modelContext) private var modelContext
    @Environment(\.calendar) private var calendar
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: \Routine.sortIndex) private var routines: [Routine]
    @Query(sort: \WorkoutSession.startedAt) private var sessions: [WorkoutSession]
    @Query(filter: #Predicate<WorkoutTemplate> { !$0.isArchived }, sort: \WorkoutTemplate.sortIndex)
    private var templates: [WorkoutTemplate]

    @State private var selectedDay = Date.now
    /// Moves on at midnight and when the app comes back.
    @State private var today = Date.now
    @State private var steps: StepSummary?
    @State private var signals: EnergySignals?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                Text("Welcome Back")
                    .font(.peakScreenTitle)
                    .foregroundStyle(.peakTextPrimary)
                    .accessibilityAddTraits(.isHeader)
                    .onTapGesture(count: 2) { showToday() }
                    .accessibilityAction(named: Text("Show today")) { showToday() }

                WeekStrip(selection: $selectedDay, today: today, workoutDays: workoutDays)

                workoutCards

                VStack(alignment: .leading, spacing: Spacing.small) {
                    SectionHeader("Dashboard")
                    StepsCard(state: stepsState, goal: settings.stepGoal) {
                        Task { await health.requestAccess() }
                    }
                    GlassEffectContainer(spacing: Spacing.medium) {
                        HStack(spacing: Spacing.medium) {
                            EnergyTile(result: isToday ? energy : nil)
                            WaterTile(day: selectedDay, isFuture: isFuture, calendar: calendar)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.vertical, Spacing.medium)
        }
        .background(.peakCanvas)
        .task(id: healthKey) {
            await loadHealth()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { today = .now }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            today = .now
        }
        #if DEBUG
            .onAppear(perform: applyLaunchArguments)
        #endif
    }

    // MARK: Day

    private var isToday: Bool { calendar.isDate(selectedDay, inSameDayAs: today) }
    private var isFuture: Bool { calendar.startOfDay(for: selectedDay) > calendar.startOfDay(for: today) }

    private var planner: DayPlanner { DayPlanner(calendar: calendar) }

    private var overview: DayOverview {
        planner.overview(of: selectedDay, today: today, routines: routines, sessions: sessions)
    }

    private var workoutDays: Set<Date> {
        planner.workoutDays(
            in: RoutineScheduler(calendar: calendar).week(containing: selectedDay),
            today: today, routines: routines, sessions: sessions
        )
    }

    private func showToday() {
        withAnimation(.smooth) { selectedDay = today }
    }

    // MARK: Workouts

    @ViewBuilder
    private var workoutCards: some View {
        let overview = overview
        let label =
            isToday ? Text("Today's Workout") : Text(selectedDay, format: .dateTime.weekday(.wide).day().month(.wide))
        VStack(spacing: Spacing.medium) {
            if overview.workouts.isEmpty {
                let state: TodayWorkoutCard.State =
                    isFuture || isToday
                    ? (overview.hasActiveRoutine ? .restDay(next: overview.nextWorkoutDay) : .noRoutine)
                    : .noWorkout
                TodayWorkoutCard(label: label, state: state, action: openSettings)
            }
            ForEach(Array(overview.workouts.enumerated()), id: \.offset) { _, workout in
                TodayWorkoutCard(label: label, state: state(of: workout), action: action(for: workout))
            }
        }
        .contextMenu {
            if isToday && !templates.isEmpty {
                Menu {
                    ForEach(templates) { template in
                        Button(template.name) {
                            launcher.start(template, routine: nil, in: modelContext)
                        }
                    }
                } label: {
                    Label("Start Another Workout", systemImage: "plus")
                }
            }
        }
    }

    private func state(of workout: DayWorkout) -> TodayWorkoutCard.State {
        switch workout {
        case .planned(let template, _):
            .planned(name: template.name, movements: template.movementCount, sets: template.setCount)
        case .active(let session):
            .active(name: session.title, timerStart: session.startedAt.addingTimeInterval(session.pausedTotal))
        case .completed(let session):
            .completed(
                name: session.title,
                duration: session.duration(),
                movementsDone: session.completedMovementCount,
                movements: session.orderedExercises.count
            )
        }
    }

    /// Only today's workouts start or resume; other days are for looking, so their cards have no button.
    private func action(for workout: DayWorkout) -> (() -> Void)? {
        guard isToday else { return nil }
        switch workout {
        case .planned(let template, let routine):
            return { launcher.start(template, routine: routine, in: modelContext) }
        case .active(let session):
            return { launcher.resume(session) }
        case .completed:
            return nil
        }
    }

    // MARK: Dashboard

    private var stepsState: StepsCard.State {
        switch health.status {
        case .unavailable: .unavailable
        case .notDetermined: .needsAccess
        case .denied: .denied
        case .connected: isFuture ? .future : steps.map { .steps($0) } ?? .loading
        }
    }

    private var energy: EnergyResult {
        let planned: WorkoutTemplate? =
            switch overview.firstPending {
            case .planned(let template, _)?: template
            case .active(let session)?: session.template
            default: nil
            }
        let input = planner.energyInput(now: .now, sessions: sessions, planned: planned)
        return EnergyEngine(calendar: calendar).evaluate(input.with(signals ?? .none))
    }

    /// Health data reloads when the day, the access or the data changes.
    private var healthKey: HealthKey {
        HealthKey(day: calendar.startOfDay(for: selectedDay), status: health.status, revision: health.revision)
    }

    private struct HealthKey: Equatable {
        var day: Date
        var status: HealthAuthorization
        var revision: Int
    }

    private func loadHealth() async {
        if health.status == .notDetermined {
            await health.refresh()
        }
        guard health.status == .connected else { return }
        let day = selectedDay
        steps = nil
        steps = try? await health.service.steps(on: day)
        if calendar.isDate(day, inSameDayAs: .now) {
            signals = await health.service.energySignals(on: day)
        }
    }

    #if DEBUG
        /// Screenshot helpers: `-PeakHomeDay yesterday|tomorrow|nextWeek` selects that day.
        private func applyLaunchArguments() {
            // A bare "-1" would be read as another argument, hence the words.
            let offsets = ["yesterday": -1, "tomorrow": 1, "nextWeek": 7]
            let offset = offsets[UserDefaults.standard.string(forKey: "PeakHomeDay") ?? ""] ?? 0
            if offset != 0, let day = calendar.date(byAdding: .day, value: offset, to: today) {
                selectedDay = day
            }
            // `-PeakStartWorkout YES` starts the first workout, to see the running state.
            if UserDefaults.standard.bool(forKey: "PeakStartWorkout"), let template = templates.first {
                launcher.start(template, routine: nil, in: modelContext)
                launcher.presented = nil
            }
        }
    #endif
}

#if DEBUG
    #Preview("Dark") {
        HomeView {}
            .previewEnvironment()
            .preferredColorScheme(.dark)
    }

    #Preview("Light") {
        HomeView {}
            .previewEnvironment()
            .preferredColorScheme(.light)
    }
#endif
