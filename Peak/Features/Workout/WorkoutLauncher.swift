import Foundation
import Observation
import PeakCore
import SwiftData

/// Starts and reopens workouts from anywhere (the Home card, the bottom accessory, History). The root view presents
/// `presented` as the workout sheet, and the "Start anyway?" alert while `pendingStart` waits. A workout entered after
/// the fact (F11-13) opens in the same sheet, which shows it without the timer.
@MainActor
@Observable
final class WorkoutLauncher {
    /// A start held back because energy is Not Ready (docs/ENERGY_LEVEL.md): the alert asks, it never blocks.
    struct PendingStart {
        let template: WorkoutTemplate
        let routine: Routine?
        let rule: ProgressionRule
        let context: ModelContext
    }

    /// The session whose sheet is open.
    var presented: WorkoutSession?
    /// Today's energy level, kept current by Home.
    var energyLevel: EnergyLevel?
    /// The start waiting for "Start anyway?".
    var pendingStart: PendingStart?

    /// Starts `template`, or reopens the running session: only one workout runs at a time. `rule` sets the targets.
    /// While energy is Not Ready the start waits for `confirmPendingStart()`.
    func start(_ template: WorkoutTemplate, routine: Routine?, rule: ProgressionRule, in context: ModelContext) {
        if let current = try? SessionRepository(context: context).current() {
            presented = current
            return
        }
        let start = PendingStart(template: template, routine: routine, rule: rule, context: context)
        if energyLevel == .notReady {
            pendingStart = start
        } else {
            begin(start)
        }
    }

    /// "Start Anyway" in the alert.
    func confirmPendingStart() {
        guard let pendingStart else { return }
        self.pendingStart = nil
        begin(pendingStart)
    }

    func resume(_ session: WorkoutSession) {
        presented = session
    }

    /// Opens `template` to be entered for `day` (F11-13), at the time and length it usually takes. Nothing runs, so
    /// neither the running workout nor energy is asked about. With `routine` the rotation moves on once saved.
    func log(
        _ template: WorkoutTemplate, routine: Routine?, on day: Date, rule: ProgressionRule, in context: ModelContext
    ) {
        let sessions = SessionRepository(context: context)
        let plan =
            (try? sessions.logPlan(for: template, on: day))
            ?? ManualLogPlan(start: day, duration: ManualLogPlan.fallbackDuration)
        let session = sessions.startLog(
            from: template, routine: routine, rule: rule, start: plan.start, duration: plan.duration)
        try? context.save()
        presented = session
    }

    /// A workout left half entered when the app was closed opens again, as a running one stays running.
    func reopenLog(in context: ModelContext) {
        guard presented == nil, let session = try? SessionRepository(context: context).openLog() else { return }
        presented = session
    }

    private func begin(_ start: PendingStart) {
        let session = SessionRepository(context: start.context)
            .start(from: start.template, routine: start.routine, rule: start.rule)
        try? start.context.save()
        presented = session
    }
}
