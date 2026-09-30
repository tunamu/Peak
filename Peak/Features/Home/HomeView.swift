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
        // The launcher asks "Start anyway?" while today's energy is Not Ready, wherever the start comes from.
        .onChange(of: isToday ? energy.level : nil, initial: true) { _, level in
            if let level { launcher.energyLevel = level }
            #if DEBUG
                // Screenshot helper: `-PeakEnergy notReady` forces the level the alert checks.
                let forced = UserDefaults.standard.string(forKey: "PeakEnergy").flatMap(EnergyLevel.init(rawValue:))
                if let forced {
                    launcher.energyLevel = forced
                }
            #endif
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
            in: WeekStrip.days(around: selectedDay, today: today, calendar: calendar),
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
        let base =
            isToday
            ? String(localized: "Today's Workout")
            : selectedDay.formatted(.dateTime.weekday(.wide).day().month(.wide))
        let isRunning = overview.workouts.contains {
            if case .active = $0 { return true }
            return false
        }
        VStack(spacing: Spacing.medium) {
            if overview.workouts.isEmpty {
                let state: TodayWorkoutCard.State =
                    isFuture || isToday
                    ? (overview.hasActiveRoutine ? .restDay(next: overview.nextWorkoutDay) : .noRoutine)
                    : .noWorkout
                TodayWorkoutCard(label: Text(verbatim: base), state: state, action: openSettings)
            }
            // Several workouts on one day stack, each named by its routine. Only one runs at a time, so while one
            // runs the others' Start waits.
            ForEach(Array(overview.workouts.enumerated()), id: \.offset) { _, workout in
                TodayWorkoutCard(
                    label: Text(verbatim: label(base, for: workout, isOneOfMany: overview.workouts.count > 1)),
                    state: state(of: workout),
                    action: action(for: workout),
                    open: open(workout)
                )
                .disabled(isRunning && workout.isPlanned)
            }
            if canStartAnother(isRunning: isRunning) {
                Menu {
                    anotherWorkoutButtons
                } label: {
                    Label("Start Another Workout", systemImage: "plus")
                        .font(.peakRow)
                        .foregroundStyle(.peakTextSecondary)
                        .frame(maxWidth: .infinity, minHeight: Metrics.minTouchTarget)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .contextMenu {
            if canStartAnother(isRunning: isRunning) {
                Menu {
                    anotherWorkoutButtons
                } label: {
                    Label("Start Another Workout", systemImage: "plus")
                }
            }
        }
    }

    /// F6-07: any template can be started today outside the plan, unless a workout already runs (one at a time).
    private func canStartAnother(isRunning: Bool) -> Bool {
        isToday && !isRunning && !templates.isEmpty
    }

    /// One button per template. The session is saved without a routine, so the rotation carries on untouched.
    private var anotherWorkoutButtons: some View {
        ForEach(templates) { template in
            Button(template.name) {
                launcher.start(template, routine: nil, rule: settings.progressionRule, in: modelContext)
            }
        }
    }

    /// "Today's Workout", and with several workouts that day "Today's Workout · Main Routine".
    private func label(_ base: String, for workout: DayWorkout, isOneOfMany: Bool) -> String {
        let routine: Routine? =
            switch workout {
            case .planned(_, let routine): routine
            case .active(let session), .completed(let session): session.routine
            }
        guard isOneOfMany, let routine else { return base }
        return "\(base) · \(routine.name)"
    }

    private func state(of workout: DayWorkout) -> TodayWorkoutCard.State {
        switch workout {
        case .planned(let template, _):
            .planned(name: template.name, movements: template.movementCount, sets: template.setCount)
        case .active(let session):
            .active(
                name: session.title,
                timerStart: session.startedAt.addingTimeInterval(session.pausedTotal),
                pausedElapsed: session.status == .paused ? session.duration() : nil
            )
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
            return { launcher.start(template, routine: routine, rule: settings.progressionRule, in: modelContext) }
        case .active(let session):
            return { togglePause(session) }
        case .completed:
            return nil
        }
    }

    /// A running workout's card opens its sheet; the button pauses or resumes it.
    private func open(_ workout: DayWorkout) -> (() -> Void)? {
        guard isToday, case .active(let session) = workout else { return nil }
        return { launcher.resume(session) }
    }

    private func togglePause(_ session: WorkoutSession) {
        let controller = WorkoutSessionController(session: session, context: modelContext)
        if session.status == .paused {
            try? controller.resume()
        } else {
            try? controller.pause()
        }
    }

}

// MARK: Dashboard

extension HomeView {

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
                launcher.start(template, routine: nil, rule: settings.progressionRule, in: modelContext)
                launcher.presented = nil
            }
            // `-PeakStartWalk YES` throws away the running workout and starts a walk (made if missing), to see C-12.
            if UserDefaults.standard.bool(forKey: "PeakStartWalk") {
                startSampleWalk()
            }
            // `-PeakPauseWorkout YES` pauses the running workout, to see the paused state.
            if UserDefaults.standard.bool(forKey: "PeakPauseWorkout"),
                let session = try? SessionRepository(context: modelContext).current()
            {
                try? WorkoutSessionController(session: session, context: modelContext).pause()
            }
            // `-PeakCompleteMovement YES` completes the running workout's first movement.
            if UserDefaults.standard.bool(forKey: "PeakCompleteMovement"),
                let session = try? SessionRepository(context: modelContext).current(),
                let first = session.orderedExercises.first
            {
                try? WorkoutSessionController(session: session, context: modelContext).completeMovement(first)
            }
            // `-PeakOpenWorkout YES` opens the running workout's sheet.
            if UserDefaults.standard.bool(forKey: "PeakOpenWorkout"),
                let session = try? SessionRepository(context: modelContext).current()
            {
                launcher.resume(session)
            }
        }

        private func startSampleWalk() {
            let sessions = SessionRepository(context: modelContext)
            if let current = try? sessions.current() {
                sessions.discard(current)
            }
            let templates = TemplateRepository(context: modelContext)
            let template: WorkoutTemplate
            if let walking = self.templates.first(where: { $0.name == "Walking" }) {
                template = walking
            } else {
                guard
                    let walk = try? ExerciseRepository(context: modelContext)
                        .findOrCreate(name: "Incline Walk", kind: .cardio),
                    let created = try? templates.create(name: "Walking", kind: .cardio)
                else { return }
                templates.setItems([(walk, 1)], of: created)
                template = created
            }
            let session = sessions.start(from: template, rule: settings.progressionRule)
            if let segment = session.orderedExercises.first?.orderedSegments.first {
                segment.speedKmh = 5.5
                segment.inclinePercent = 12
                segment.durationSec = 1_800
            }
            try? modelContext.save()
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
