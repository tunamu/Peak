import Observation
import PeakCore
import SwiftData

/// Starts and reopens workouts from anywhere (the Home card, the bottom accessory). The root view presents
/// `presented` as the workout sheet.
@MainActor
@Observable
final class WorkoutLauncher {
    /// The session whose sheet is open.
    var presented: WorkoutSession?

    /// Starts `template`, or reopens the running session: only one workout runs at a time.
    func start(_ template: WorkoutTemplate, routine: Routine?, in context: ModelContext) {
        let sessions = SessionRepository(context: context)
        if let current = try? sessions.current() {
            presented = current
            return
        }
        let session = sessions.start(from: template, routine: routine)
        try? context.save()
        presented = session
    }

    func resume(_ session: WorkoutSession) {
        presented = session
    }
}
