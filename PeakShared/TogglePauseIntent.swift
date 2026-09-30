import AppIntents
import PeakCore
import SwiftData

// Compiled into both the app and the widget extension: the Live Activity's button names the intent, and iOS runs it
// in the app's process. Kept out of PeakCore because App Intents are found in the targets, not in packages.

/// The Live Activity's Pause/Resume button. Runs in the app's process, even when the app is not open.
struct TogglePauseIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Pause or Resume Workout"

    @MainActor
    func perform() async throws -> some IntentResult {
        let container = try WorkoutActivity.container ?? PeakStore.makeContainer(.appGroup)
        let context = container.mainContext
        if let session = try SessionRepository(context: context).current() {
            let controller = WorkoutSessionController(session: session, context: context)
            if session.status == .paused {
                try controller.resume()
            } else {
                try controller.pause()
            }
        }
        await WorkoutActivity.sync(context: context)
        return .result()
    }
}
