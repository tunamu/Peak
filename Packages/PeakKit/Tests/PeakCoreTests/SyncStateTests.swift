import CloudKit
import Foundation
import PeakCore
import Testing

/// F8-04: what the iCloud row says for each account state and sync outcome.
@Suite struct SyncStateTests {
    static let noon = Date(timeIntervalSince1970: 1_790_000_000)

    /// What CloudKit sent on 2026-10-01 for a full account: a partial failure whose every record is "quota exceeded".
    static func fullAccountError() -> CKError {
        let recordError = CKError(.quotaExceeded)
        let recordID = CKRecord.ID(recordName: "05AACFC1-DD23-43D5-8D27-7ED5961CCBF2")
        return CKError(.partialFailure, userInfo: [CKPartialErrorsByItemIDKey: [recordID: recordError]])
    }

    @Test func accountStatesWinOverSyncResults() {
        #expect(SyncState().status == .checking)
        #expect(SyncState(account: .noAccount, problems: [.export: .storageFull]).status == .noAccount)
        #expect(SyncState(account: .restricted).status == .restricted)
        #expect(SyncState(account: .temporarilyUnavailable).status == .unavailable)
        #expect(SyncState(account: .couldNotDetermine).status == .unavailable)
        #expect(SyncState(account: .available).status == .synced(nil))
    }

    @Test func aFullAccountReadsAsStorageFull() {
        #expect(SyncProblem(Self.fullAccountError()) == .storageFull)
        var state = SyncState(account: .available)
        state.finish(.export, succeeded: false, at: Self.noon, error: Self.fullAccountError())
        #expect(state.status == .storageFull)
    }

    /// Seen on the simulator: with a full account the download goes through and the upload fails. The download must
    /// not make the row say "Synced".
    @Test func aWorkingDownloadDoesNotHideAFailingUpload() {
        var state = SyncState(account: .available)
        state.finish(.export, succeeded: false, at: Self.noon, error: Self.fullAccountError())
        state.finish(.import, succeeded: true, at: Self.noon.addingTimeInterval(5), error: nil)
        #expect(state.status == .storageFull)

        state.finish(.export, succeeded: true, at: Self.noon.addingTimeInterval(60), error: nil)
        #expect(state.status == .synced(Self.noon.addingTimeInterval(60)))
    }

    @Test func theProblemToActOnFirstIsShown() {
        let state = SyncState(account: .available, problems: [.import: .offline, .export: .storageFull])
        #expect(state.status == .storageFull)
        #expect(SyncState(account: .available, problems: [.setup: .notSignedIn, .export: .other]).status == .noAccount)
    }

    @Test func errorsAreSorted() {
        #expect(SyncProblem(CKError(.quotaExceeded)) == .storageFull)
        #expect(SyncProblem(CKError(.networkUnavailable)) == .offline)
        #expect(SyncProblem(CKError(.networkFailure)) == .offline)
        #expect(SyncProblem(CKError(.notAuthenticated)) == .notSignedIn)
        #expect(SyncProblem(CKError(.serverRejectedRequest)) == .other)
        // Core Data's "no iCloud account" while setting up, as logged before sign-in on the simulator.
        #expect(SyncProblem(NSError(domain: NSCocoaErrorDomain, code: 134_400)) == .notSignedIn)
        let wrapped = NSError(
            domain: NSCocoaErrorDomain, code: 134_419, userInfo: [NSUnderlyingErrorKey: CKError(.quotaExceeded)])
        #expect(SyncProblem(wrapped) == .storageFull)
        #expect(SyncProblem(CocoaError(.fileNoSuchFile)) == .other)
    }

    /// What the app really gets for a full account: the event's error is only the domain and code.
    @Test func aPartialFailureWithoutDetailsReadsAsRejected() {
        let eventError = NSError(domain: CKError.errorDomain, code: CKError.Code.partialFailure.rawValue)
        #expect(SyncProblem(eventError) == .uploadRejected)
        var state = SyncState(account: .available)
        state.finish(.export, succeeded: false, at: Self.noon, error: eventError)
        state.finish(.import, succeeded: true, at: Self.noon, error: nil)
        #expect(state.status == .uploadRejected)
    }

    @Test func aSuccessfulTransferRecordsTheTime() {
        var state = SyncState(account: .available, problems: [.import: .offline])
        state.finish(.import, succeeded: true, at: Self.noon, error: nil)
        #expect(state.status == .synced(Self.noon))
    }

    /// Setting up sync moves no data: it clears its own problem (no account before sign-in) but is not "last synced".
    @Test func aSuccessfulSetupIsNotASync() {
        var state = SyncState(account: .available, problems: [.setup: .notSignedIn])
        state.finish(.setup, succeeded: true, at: Self.noon, error: nil)
        #expect(state.status == .synced(nil))
    }

    @Test func aFailureWithoutAnErrorChangesNothing() {
        var state = SyncState(account: .available, lastSync: Self.noon)
        state.finish(.export, succeeded: false, at: Self.noon, error: nil)
        #expect(state.status == .synced(Self.noon))
    }
}
