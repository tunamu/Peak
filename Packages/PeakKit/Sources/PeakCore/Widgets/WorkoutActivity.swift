#if os(iOS)
    import ActivityKit
    import Foundation
    import SwiftData

    /// The running workout on the Lock Screen and in the Dynamic Island (C-17).
    public struct WorkoutActivityAttributes: ActivityAttributes {
        public typealias ContentState = WorkoutActivityState

        public var sessionID: UUID
        public var workoutName: String

        public init(sessionID: UUID, workoutName: String) {
            self.sessionID = sessionID
            self.workoutName = workoutName
        }
    }

    /// Keeps the Live Activity in step with the store: one activity for the running or paused session, none
    /// otherwise. Called after every save and when the app comes back, so starting, pausing, logging sets, finishing,
    /// discarding and a relaunch after the app was killed all end in the right state.
    @MainActor
    public enum WorkoutActivity {
        /// The container the app runs with, so intents in the app's process work on the same data.
        public static var container: ModelContainer?

        public static func sync(context: ModelContext) async {
            let session = try? SessionRepository(context: context).current()
            await apply(session.map { Running(id: $0.id, name: $0.title, state: WorkoutActivityState(session: $0)) })
        }

        /// The running session, as values that can leave the main actor.
        private struct Running: Sendable {
            let id: UUID
            let name: String
            let state: WorkoutActivityState
        }

        /// ActivityKit's side, away from the main actor: only the values cross over, never an `Activity`.
        private nonisolated static func apply(_ running: Running?) async {
            let activities = Activity<WorkoutActivityAttributes>.activities
            for activity in activities where activity.attributes.sessionID != running?.id {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            guard let running else { return }
            let content = ActivityContent(state: running.state, staleDate: nil)
            if let activity = activities.first(where: { $0.attributes.sessionID == running.id }) {
                if activity.content.state != running.state {
                    await activity.update(content)
                }
            } else if ActivityAuthorizationInfo().areActivitiesEnabled {
                // Starting needs the app in the foreground; the next sync after a relaunch starts it otherwise.
                _ = try? Activity.request(
                    attributes: WorkoutActivityAttributes(sessionID: running.id, workoutName: running.name),
                    content: content)
            }
        }
    }
#endif
