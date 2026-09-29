import Observation
import PeakCore
import SwiftData

/// Starts and reopens workouts from anywhere (the Home card, the bottom accessory). The root view presents
/// `presented` as the workout sheet, and the "Start anyway?" alert while `pendingStart` waits.
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

    private func begin(_ start: PendingStart) {
        let session = SessionRepository(context: start.context)
            .start(from: start.template, routine: start.routine, rule: start.rule)
        try? start.context.save()
        presented = session
    }
}
