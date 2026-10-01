import CloudKit
import Foundation

/// What the iCloud row in Settings shows (F8-04). Whatever it says, the app keeps working on the device.
public enum SyncStatus: Equatable, Sendable {
    /// The iCloud account has not been asked yet.
    case checking
    /// Not signed in to iCloud.
    case noAccount
    /// iCloud is blocked on the device, for example by Screen Time or a profile.
    case restricted
    /// iCloud cannot answer right now.
    case unavailable
    /// The iCloud account has no room left: new data stays on the device.
    case storageFull
    /// iCloud turned down some uploads without saying why; most often the account is full.
    case uploadRejected
    case offline
    /// The last sync failed for another reason; CloudKit tries again on its own.
    case failed
    /// Signed in, and the last sync went through; the date of the last finished sync since launch, if any.
    case synced(Date?)
}

/// Why a sync did not go through, read from the error of a CloudKit event.
public enum SyncProblem: Equatable, Sendable {
    case storageFull, offline, notSignedIn, other
    /// A partial failure without its per-record errors. Core Data rebuilds an event's error from the domain and code
    /// it stored, so the app never sees why (checked on the simulator with a full account: `CKErrorDomain` 2, empty
    /// `userInfo`); the log has the reason, usually "quota exceeded".
    case uploadRejected

    /// Looks inside a partial failure at the per-record errors (a full account fails every record that way) and
    /// inside Core Data's wrapping errors.
    public init(_ error: any Error) {
        let nsError = error as NSError
        guard nsError.domain == CKError.errorDomain else {
            // Core Data's "no iCloud account" when setting up sync.
            if nsError.domain == NSCocoaErrorDomain && nsError.code == 134_400 {
                self = .notSignedIn
            } else if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? any Error {
                self.init(underlying)
            } else {
                self = .other
            }
            return
        }
        let error = CKError(_nsError: nsError)
        let codes: Set<CKError.Code>
        if error.code == .partialFailure {
            guard let partial = error.partialErrorsByItemID, !partial.isEmpty else {
                self = .uploadRejected
                return
            }
            codes = Set(partial.values.compactMap { ($0 as? CKError)?.code })
        } else {
            codes = [error.code]
        }
        if codes.contains(.quotaExceeded) {
            self = .storageFull
        } else if codes.contains(.notAuthenticated) {
            self = .notSignedIn
        } else if !codes.isDisjoint(with: [.networkUnavailable, .networkFailure]) {
            self = .offline
        } else {
            self = .other
        }
    }
}

/// The kinds of CloudKit event; each has its own outcome, because a download can work while uploads fail (a full
/// account still downloads).
public enum SyncEventKind: Hashable, Sendable {
    case setup, `import`, export
}

/// The iCloud account and the outcome of the last event of each kind, folded into one `SyncStatus`.
public struct SyncState: Equatable, Sendable {
    /// nil until the account has been asked.
    public var account: CKAccountStatus?
    /// The last failure of each kind of event; an event of the same kind that succeeds clears it.
    public var problems: [SyncEventKind: SyncProblem]
    /// The end of the last import or export that went through.
    public var lastSync: Date?

    public init(
        account: CKAccountStatus? = nil, problems: [SyncEventKind: SyncProblem] = [:], lastSync: Date? = nil
    ) {
        self.account = account
        self.problems = problems
        self.lastSync = lastSync
    }

    /// A finished CloudKit event. Success clears that kind's problem and, for an import or export, records the time;
    /// a failure with an error sets that kind's problem. Setting up sync moves no data, so it never counts as a sync.
    public mutating func finish(_ kind: SyncEventKind, succeeded: Bool, at date: Date, error: (any Error)?) {
        if succeeded {
            problems[kind] = nil
            if kind != .setup { lastSync = date }
        } else if let error {
            problems[kind] = SyncProblem(error)
        }
    }

    /// The problem the row shows when there are several: the one the user can act on first.
    public var problem: SyncProblem? {
        let order: [SyncProblem] = [.notSignedIn, .storageFull, .uploadRejected, .offline, .other]
        return order.first { problems.values.contains($0) }
    }

    public var status: SyncStatus {
        switch account {
        case nil: .checking
        case .noAccount: .noAccount
        case .restricted: .restricted
        case .couldNotDetermine, .temporarilyUnavailable: .unavailable
        case .available:
            switch problem {
            case nil: .synced(lastSync)
            case .storageFull: .storageFull
            case .uploadRejected: .uploadRejected
            case .offline: .offline
            case .notSignedIn: .noAccount
            case .other: .failed
            }
        @unknown default: .unavailable
        }
    }
}
