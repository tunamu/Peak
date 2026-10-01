import Foundation
import SwiftData

/// The app's `peak://` links (F9-04): widgets, the Live Activity and shortcuts open the app with one of these.
public enum PeakLink: Hashable, Sendable, CaseIterable {
    /// `peak://home`
    case home
    /// `peak://settings`
    case settings
    /// `peak://workout/start`: starts today's next workout, or reopens the running one.
    case startWorkout
    /// `peak://workout/open`: opens the running workout.
    case openWorkout

    public static let scheme = "peak"

    /// Reads a link; anything else, including another scheme or an unknown path, is nil. Case and a trailing slash
    /// do not matter.
    public init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme else { return nil }
        let parts = ([url.host() ?? ""] + url.pathComponents.filter { $0 != "/" })
            .map { $0.lowercased() }
            .filter { !$0.isEmpty }
        switch parts {
        case ["home"]: self = .home
        case ["settings"]: self = .settings
        case ["workout", "start"]: self = .startWorkout
        case ["workout", "open"]: self = .openWorkout
        default: return nil
        }
    }

    public var url: URL {
        let path =
            switch self {
            case .home: "home"
            case .settings: "settings"
            case .startWorkout: "workout/start"
            case .openWorkout: "workout/open"
            }
        // A fixed, valid string: building it cannot fail.
        return URL(string: "\(Self.scheme)://\(path)") ?? URL(filePath: "/")
    }
}

extension DayPlanner {
    /// Today's workout the Start button means, read from the store: the running one, else the first planned one
    /// not done yet. nil on a rest day or without routines.
    public func nextWorkoutToday(in context: ModelContext, now: Date = .now) throws -> DayWorkout? {
        let overview = overview(
            of: now,
            today: now,
            routines: try context.fetch(FetchDescriptor<Routine>()),
            sessions: try context.fetch(FetchDescriptor<WorkoutSession>())
        )
        return overview.firstPending
    }
}
