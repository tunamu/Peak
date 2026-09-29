import Foundation
import Observation

/// Whether Peak may use Apple Health.
///
/// HealthKit never reveals whether *read* access was granted (a privacy rule), so `connected` means the permission
/// sheet was answered and water may be written. Reads that were denied simply return no data.
public enum HealthAuthorization: Hashable, Sendable {
    /// No Health on this device (for example, an iPad without the Health app).
    case unavailable
    /// The permission sheet has not been shown yet.
    case notDetermined
    case connected
    /// Turned off in the Health app.
    case denied
}

/// Steps for one day and the daily average of the seven days before it.
public struct StepSummary: Hashable, Sendable {
    public var count: Int
    /// Average of the previous seven days that have steps; `nil` without any.
    public var dailyAverage: Int?

    public init(count: Int, dailyAverage: Int?) {
        self.count = count
        self.dailyAverage = dailyAverage
    }
}

/// The Health inputs of the energy score (levels B and C of docs/ENERGY_LEVEL.md).
public struct EnergySignals: Hashable, Sendable {
    /// Last night's sleep; `nil` without sleep data.
    public var sleepDuration: TimeInterval?
    /// The day's HRV (SDNN, ms) and the previous days' daily averages, oldest first.
    public var heartRateVariability: Double?
    public var heartRateVariabilityHistory: [Double]
    /// The day's resting heart rate (bpm) and the previous days' values, oldest first.
    public var restingHeartRate: Double?
    public var restingHeartRateHistory: [Double]

    public init(
        sleepDuration: TimeInterval? = nil,
        heartRateVariability: Double? = nil,
        heartRateVariabilityHistory: [Double] = [],
        restingHeartRate: Double? = nil,
        restingHeartRateHistory: [Double] = []
    ) {
        self.sleepDuration = sleepDuration
        self.heartRateVariability = heartRateVariability
        self.heartRateVariabilityHistory = heartRateVariabilityHistory
        self.restingHeartRate = restingHeartRate
        self.restingHeartRateHistory = restingHeartRateHistory
    }

    /// No Health data: only the workout rules (level A) apply.
    public static let none = EnergySignals()
}

/// A finished workout as Health stores it: strength training, or walking with its distance when known.
public struct HealthWorkout: Hashable, Sendable {
    public var start: Date
    public var end: Date
    /// Paused time; Health leaves it out of the workout's duration.
    public var pausedDuration: TimeInterval
    public var isWalk: Bool
    public var distanceKm: Double?

    public init(
        start: Date, end: Date, pausedDuration: TimeInterval = 0, isWalk: Bool = false, distanceKm: Double? = nil
    ) {
        self.start = start
        self.end = end
        self.pausedDuration = pausedDuration
        self.isWalk = isWalk
        self.distanceKm = distanceKm
    }
}

/// Apple Health, behind a protocol: `HealthKitService` in the app, `MockHealthService` in previews, tests and
/// screenshots (docs/HEALTHKIT.md).
@MainActor
public protocol HealthService: AnyObject {
    func authorizationStatus() async -> HealthAuthorization
    /// Shows the system permission sheet while access is undetermined; afterwards changes happen in the Health app.
    func requestAuthorization() async
    func steps(on day: Date) async throws -> StepSummary
    /// Sleep of the night before `day`, and heart data up to `day`. Missing data stays `nil`.
    func energySignals(on day: Date) async -> EnergySignals
    /// Replaces the day's water sample with one total (one sample per day, so Remove stays consistent).
    func setWaterTotal(_ milliliters: Int, on day: Date) async throws
    /// Saves a finished workout and returns the Health workout's ID.
    func saveWorkout(_ workout: HealthWorkout) async throws -> UUID
    /// Calls `onChange` whenever step data changes, also in the background.
    func observeSteps(_ onChange: @escaping @MainActor @Sendable () -> Void)
}

/// The app's link to Apple Health, shared through the environment: the access status for Settings and the Home
/// cards, and a revision that goes up when Health data changes so views reload.
@MainActor
@Observable
public final class HealthConnection {
    public private(set) var status = HealthAuthorization.notDetermined
    /// Goes up on every step change reported by Health.
    public private(set) var revision = 0

    @ObservationIgnored public let service: any HealthService
    @ObservationIgnored private var isObserving = false

    public init(service: any HealthService) {
        self.service = service
    }

    public func refresh() async {
        status = await service.authorizationStatus()
        if status == .connected && !isObserving {
            isObserving = true
            service.observeSteps { [weak self] in
                self?.revision += 1
            }
        }
    }

    public func requestAccess() async {
        await service.requestAuthorization()
        await refresh()
        revision += 1
    }
}

/// Fixed Health data for previews, tests and simulator screenshots (the simulator has no Health data).
@MainActor
public final class MockHealthService: HealthService {
    public var status: HealthAuthorization
    public var stepCount: Int
    public var dailyAverage: Int?
    public var signals: EnergySignals
    /// The last total written per day, by start of day.
    public private(set) var waterTotals: [Date: Int] = [:]
    private let calendar: Calendar

    public init(
        status: HealthAuthorization = .connected,
        stepCount: Int = 7_598,
        dailyAverage: Int? = 6_771,
        signals: EnergySignals = .sample,
        calendar: Calendar = .current
    ) {
        self.status = status
        self.stepCount = stepCount
        self.dailyAverage = dailyAverage
        self.signals = signals
        self.calendar = calendar
    }

    public func authorizationStatus() async -> HealthAuthorization { status }

    public func requestAuthorization() async {
        if status == .notDetermined {
            status = .connected
        }
    }

    /// Today has `stepCount`; earlier days have the average; later days have nothing yet.
    public func steps(on day: Date) async throws -> StepSummary {
        let today = calendar.startOfDay(for: .now)
        let start = calendar.startOfDay(for: day)
        let count = start == today ? stepCount : start < today ? dailyAverage ?? 0 : 0
        return StepSummary(count: count, dailyAverage: dailyAverage)
    }

    public func energySignals(on day: Date) async -> EnergySignals { signals }

    public func setWaterTotal(_ milliliters: Int, on day: Date) async throws {
        waterTotals[calendar.startOfDay(for: day)] = milliliters
    }

    /// Workouts saved so far, oldest first.
    public private(set) var savedWorkouts: [HealthWorkout] = []

    public func saveWorkout(_ workout: HealthWorkout) async throws -> UUID {
        savedWorkouts.append(workout)
        return UUID()
    }

    public func observeSteps(_ onChange: @escaping @MainActor @Sendable () -> Void) {}
}

extension EnergySignals {
    /// A rested night and a steady week of Apple Watch data.
    public static let sample = EnergySignals(
        sleepDuration: 7 * 3_600 + 20 * 60,
        heartRateVariability: 54,
        heartRateVariabilityHistory: [55, 58, 54, 57, 56, 53, 55],
        restingHeartRate: 58,
        restingHeartRateHistory: [57, 58, 56, 57, 58, 57, 56]
    )
}

extension EnergyInput {
    /// Adds the Health inputs to the workout inputs.
    public func with(_ signals: EnergySignals) -> EnergyInput {
        var input = self
        input.sleepDuration = signals.sleepDuration
        input.heartRateVariability = signals.heartRateVariability
        input.heartRateVariabilityHistory = signals.heartRateVariabilityHistory
        input.restingHeartRate = signals.restingHeartRate
        input.restingHeartRateHistory = signals.restingHeartRateHistory
        return input
    }
}
