import CloudKit
import CoreData
import Foundation
import Observation
import SwiftData

/// Watches iCloud sync in the app: keeps the status the Settings row shows (F8-04), and runs `Deduplicator` at launch
/// and after every iCloud import (F8-02), on the main context so open screens update.
///
/// Imports arrive in bursts, so a deduplication pass waits a moment and runs once for the burst.
@MainActor
@Observable
public final class SyncMonitor {
    public private(set) var state = SyncState()
    public var status: SyncStatus { state.status }

    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored private let accountStatus: @MainActor () async throws -> CKAccountStatus
    @ObservationIgnored private let delay: Duration
    @ObservationIgnored private var observers: [any NSObjectProtocol] = []
    @ObservationIgnored private var pendingDeduplication: Task<Void, Never>?

    /// - Parameters:
    ///   - accountStatus: Asks iCloud for the account; previews pass a fixed answer.
    ///   - delay: How long a deduplication pass waits for the rest of an import burst.
    public init(
        container: ModelContainer,
        accountStatus: (@MainActor () async throws -> CKAccountStatus)? = nil,
        delay: Duration = .seconds(1)
    ) {
        self.container = container
        self.accountStatus =
            accountStatus ?? {
                try await CKContainer(identifier: PeakStore.cloudKitContainerID).accountStatus()
            }
        self.delay = delay
    }

    isolated deinit {
        pendingDeduplication?.cancel()
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Starts listening to sync events and account changes, asks for the account, and schedules a first
    /// deduplication pass for what is already in the store.
    public func start() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers.append(
            center.addObserver(
                forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main
            ) { [weak self] notification in
                let key = NSPersistentCloudKitContainer.eventNotificationUserInfoKey
                guard let event = notification.userInfo?[key] as? NSPersistentCloudKitContainer.Event,
                    let endDate = event.endDate
                else { return }
                let kind: SyncEventKind =
                    switch event.type {
                    case .setup: .setup
                    case .import: .import
                    default: .export
                    }
                let succeeded = event.succeeded
                let error = event.error
                MainActor.assumeIsolated {
                    self?.finished(kind, succeeded: succeeded, at: endDate, error: error)
                }
            })
        observers.append(
            center.addObserver(forName: .CKAccountChanged, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    Task { await self.refreshAccount() }
                }
            })
        Task { await refreshAccount() }
        scheduleDeduplication()
    }

    /// Asks iCloud for the account again, such as when Settings opens.
    public func refreshAccount() async {
        state.account = (try? await accountStatus()) ?? .couldNotDetermine
    }

    // MARK: Private

    private func finished(_ kind: SyncEventKind, succeeded: Bool, at date: Date, error: (any Error)?) {
        state.finish(kind, succeeded: succeeded, at: date, error: error)
        if kind == .import && succeeded {
            scheduleDeduplication()
        }
    }

    private func scheduleDeduplication() {
        pendingDeduplication?.cancel()
        pendingDeduplication = Task { [weak self, delay] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            // A pass that fails leaves the store as it was; the next import runs it again.
            _ = try? Deduplicator.run(in: container.mainContext)
        }
    }
}
