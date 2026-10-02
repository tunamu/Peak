import Foundation
import PeakCore
import SwiftData

/// The store the app runs on, and whether it syncs with iCloud. Sync is opt-in and per device (off until the user
/// turns it on in Settings), so nobody's data leaves the iPhone without their choice.
///
/// SwiftData decides about CloudKit when a container opens, so turning sync on or off opens the same store again
/// with the new setting; `generation` changes so the views rebuild on the new container.
@MainActor
@Observable
final class AppData {
    static let syncPreferenceKey = "iCloudSyncEnabled"

    /// Whether iCloud Sync is offered at all. Off for 1.0 (ADR 0024): the two-device check has not been done, so
    /// Settings and onboarding hide the switch and the store never opens with CloudKit. Everything else stays in
    /// place; turning it on is this one line (and deploying the CloudKit schema to production first).
    /// Debug builds can try it with `-PeakICloudSync YES`.
    static var isSyncAvailable: Bool {
        #if DEBUG
            if UserDefaults.standard.bool(forKey: "PeakICloudSync") { return true }
        #endif
        return false
    }

    private(set) var container: ModelContainer
    /// Present only while sync is on.
    private(set) var sync: SyncMonitor?
    private(set) var generation = 0

    var isSyncEnabled: Bool { sync != nil }

    @ObservationIgnored private let preferences: UserDefaults
    @ObservationIgnored private let open: (_ syncs: Bool) throws -> ModelContainer

    /// - Parameters:
    ///   - preferences: Where the choice is kept: the app's own defaults, not the App Group's (the widget never syncs).
    ///   - open: Opens the store, syncing or not; previews pass an in-memory one.
    init(
        preferences: UserDefaults = .standard,
        open: @escaping (_ syncs: Bool) throws -> ModelContainer = {
            try PeakStore.makeContainer(.appGroup, syncsWithCloudKit: $0)
        }
    ) throws {
        self.preferences = preferences
        self.open = open
        let syncs = Self.isSyncAvailable && preferences.bool(forKey: Self.syncPreferenceKey)
        container = try open(syncs)
        if syncs {
            sync = Self.startSync(on: container)
        }
        // The Live Activity's Pause/Resume intent runs in this process: it works on the same container.
        WorkoutActivity.container = container
    }

    /// Opens the store again with sync on or off. Pending changes are saved first. The data stays on the device
    /// either way; turning sync off leaves what is already in iCloud there.
    func setSyncEnabled(_ enabled: Bool) throws {
        guard enabled != isSyncEnabled, !enabled || Self.isSyncAvailable else { return }
        try container.mainContext.save()
        let reopened = try open(enabled)
        sync = nil
        container = reopened
        WorkoutActivity.container = reopened
        if enabled {
            sync = Self.startSync(on: reopened)
        }
        preferences.set(enabled, forKey: Self.syncPreferenceKey)
        generation += 1
    }

    private static func startSync(on container: ModelContainer) -> SyncMonitor {
        let monitor = SyncMonitor(container: container)
        monitor.start()
        return monitor
    }
}
