import HealthKit
import Observation

/// Whether Peak may use Apple Health, for the Settings row. The full HealthService arrives with the Home screen (F5).
///
/// HealthKit never reveals whether *read* access was granted (a privacy rule), so the status comes from *write* access
/// to water, which Peak always asks for together with the rest.
@MainActor
@Observable
final class HealthAccess {
    enum Status {
        case unavailable
        case notDetermined
        case connected
        case denied
    }

    private(set) var status = Status.notDetermined

    @ObservationIgnored private let store = HKHealthStore()

    static let writeTypes: Set<HKSampleType> = [HKQuantityType(.dietaryWater), HKObjectType.workoutType()]
    static let readTypes: Set<HKObjectType> = [
        HKQuantityType(.stepCount), HKCategoryType(.sleepAnalysis), HKQuantityType(.heartRateVariabilitySDNN),
        HKQuantityType(.restingHeartRate), HKQuantityType(.dietaryWater), HKObjectType.workoutType(),
    ]

    func refresh() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            status = .unavailable
            return
        }
        // Ask HealthKit whether the permission sheet would still appear; only then is "Connect" meaningful.
        let request = try? await store.statusForAuthorizationRequest(toShare: Self.writeTypes, read: Self.readTypes)
        if request == .shouldRequest {
            status = .notDetermined
            return
        }
        status =
            switch store.authorizationStatus(for: HKQuantityType(.dietaryWater)) {
            case .sharingAuthorized: .connected
            case .sharingDenied: .denied
            default: .notDetermined
            }
    }

    /// Shows the system permission sheet. It only appears while access is undetermined; after that, changes happen in
    /// the Health app.
    func requestAccess() async {
        do {
            try await store.requestAuthorization(toShare: Self.writeTypes, read: Self.readTypes)
        } catch {
            // The sheet could not be shown (for example, no Health on this device); the status stays as it is.
        }
        await refresh()
    }
}
