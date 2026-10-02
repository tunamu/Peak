import HealthKit
import PeakCore

/// Apple Health through HealthKit (docs/HEALTHKIT.md). Nothing read here is stored in SwiftData (Guideline 5.1.3).
final class HealthKitService: HealthService {
    private let store = HKHealthStore()
    private var stepObserver: HKObserverQuery?
    private var calendar: Calendar { .current }

    static let writeTypes: Set<HKSampleType> = [
        HKQuantityType(.dietaryWater), HKObjectType.workoutType(), HKQuantityType(.distanceWalkingRunning),
    ]
    static let readTypes: Set<HKObjectType> = [
        HKQuantityType(.stepCount), HKCategoryType(.sleepAnalysis), HKQuantityType(.heartRateVariabilitySDNN),
        HKQuantityType(.restingHeartRate), HKQuantityType(.dietaryWater),
    ]

    // MARK: Access

    func authorizationStatus() async -> HealthAuthorization {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        // Ask whether the permission sheet would still appear; only then is "Connect" meaningful.
        let request = try? await store.statusForAuthorizationRequest(toShare: Self.writeTypes, read: Self.readTypes)
        if request == .shouldRequest {
            return .notDetermined
        }
        // Read access is never revealed, so the status comes from write access to water, asked for with the rest.
        return switch store.authorizationStatus(for: HKQuantityType(.dietaryWater)) {
        case .sharingAuthorized: .connected
        case .sharingDenied: .denied
        default: .notDetermined
        }
    }

    func requestAuthorization() async {
        // Fails only when the sheet cannot be shown (no Health on this device); the status then stays as it is.
        try? await store.requestAuthorization(toShare: Self.writeTypes, read: Self.readTypes)
    }

    // MARK: Steps

    func steps(on day: Date) async throws -> StepSummary {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start),
            let weekStart = calendar.date(byAdding: .day, value: -7, to: start)
        else { return StepSummary(count: 0, dailyAverage: nil) }

        // One statistics query per day, like the Health app: it removes the overlap between iPhone and Watch.
        let daily = try await dailyStatistics(.stepCount, options: .cumulativeSum, from: weekStart, to: end) {
            $0.sumQuantity()?.doubleValue(for: .count())
        }
        let previous = daily.filter { $0.key < start && $0.value > 0 }.map(\.value)
        return StepSummary(
            count: Int(daily[start] ?? 0),
            dailyAverage: previous.isEmpty ? nil : Int((previous.reduce(0, +) / Double(previous.count)).rounded())
        )
    }

    func observeSteps(_ onChange: @escaping @MainActor @Sendable () -> Void) {
        guard stepObserver == nil, HKHealthStore.isHealthDataAvailable() else { return }
        let query = Self.makeStepObserver(onChange)
        store.execute(query)
        stepObserver = query
        Task {
            // Wakes the app about once an hour when steps change; the widget (F9) refreshes from here.
            try? await store.enableBackgroundDelivery(for: HKQuantityType(.stepCount), frequency: .hourly)
        }
    }

    /// Built outside the main actor: HealthKit calls the handler on a background queue.
    private nonisolated static func makeStepObserver(_ onChange: @escaping @MainActor @Sendable () -> Void)
        -> HKObserverQuery
    {
        HKObserverQuery(sampleType: HKQuantityType(.stepCount), predicate: nil) { _, completionHandler, error in
            if error == nil {
                Task { @MainActor in onChange() }
            }
            completionHandler()
        }
    }

    // MARK: Energy

    func energySignals(on day: Date) async -> EnergySignals {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start),
            let weekStart = calendar.date(byAdding: .day, value: -7, to: start)
        else { return .none }

        let hrv = try? await dailyStatistics(
            .heartRateVariabilitySDNN, options: .discreteAverage, from: weekStart, to: end
        ) { $0.averageQuantity()?.doubleValue(for: .secondUnit(with: .milli)) }
        let restingHeartRate = try? await dailyStatistics(
            .restingHeartRate, options: .discreteAverage, from: weekStart, to: end
        ) { $0.averageQuantity()?.doubleValue(for: .count().unitDivided(by: .minute())) }

        return EnergySignals(
            sleepDuration: try? await sleep(before: start),
            heartRateVariability: hrv?[start],
            heartRateVariabilityHistory: Self.history(hrv, before: start),
            restingHeartRate: restingHeartRate?[start],
            restingHeartRateHistory: Self.history(restingHeartRate, before: start)
        )
    }

    /// Time asleep between 18:00 the evening before and noon. iPhone and Watch record the same night, so
    /// overlapping samples are merged before adding up.
    private func sleep(before day: Date) async throws -> TimeInterval? {
        guard let from = calendar.date(byAdding: .hour, value: -6, to: day),
            let until = calendar.date(byAdding: .hour, value: 12, to: day)
        else { return nil }
        let descriptor = HKSampleQueryDescriptor(
            predicates: [
                .categorySample(
                    type: HKCategoryType(.sleepAnalysis),
                    predicate: HKQuery.predicateForSamples(withStart: from, end: until)
                )
            ],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let asleep = Set(HKCategoryValueSleepAnalysis.allAsleepValues.map(\.rawValue))
        let intervals = try await descriptor.result(for: store)
            .filter { asleep.contains($0.value) }
            .map { max($0.startDate, from)...min($0.endDate, until) }
        guard !intervals.isEmpty else { return nil }

        var total: TimeInterval = 0
        var current = intervals[0]
        for interval in intervals.dropFirst() {
            if interval.lowerBound <= current.upperBound {
                current = current.lowerBound...max(current.upperBound, interval.upperBound)
            } else {
                total += current.upperBound.timeIntervalSince(current.lowerBound)
                current = interval
            }
        }
        return total + current.upperBound.timeIntervalSince(current.lowerBound)
    }

    private static func history(_ values: [Date: Double]?, before day: Date) -> [Double] {
        (values ?? [:]).filter { $0.key < day }.sorted { $0.key < $1.key }.map(\.value)
    }

    // MARK: Water

    func setWaterTotal(_ milliliters: Int, on day: Date) async throws {
        let type = HKQuantityType(.dietaryWater)
        let start = calendar.startOfDay(for: day)
        let identifier = "peak.water.\(start.formatted(.iso8601.year().month().day()))"

        guard milliliters > 0 else {
            // Nothing left that day: delete the day's sample instead of writing zero.
            let descriptor = HKSampleQueryDescriptor(
                predicates: [
                    .quantitySample(
                        type: type,
                        predicate: HKQuery.predicateForObjects(
                            withMetadataKey: HKMetadataKeySyncIdentifier, allowedValues: [identifier])
                    )
                ],
                sortDescriptors: []
            )
            let samples = try await descriptor.result(for: store)
            if !samples.isEmpty {
                try await store.delete(samples)
            }
            return
        }

        // The same sync identifier with a higher version makes HealthKit replace the day's previous sample.
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        let date = min(max(Date.now, start), end.addingTimeInterval(-60))
        let sample = HKQuantitySample(
            type: type,
            quantity: HKQuantity(unit: .literUnit(with: .milli), doubleValue: Double(milliliters)),
            start: date,
            end: date,
            metadata: [
                HKMetadataKeySyncIdentifier: identifier,
                HKMetadataKeySyncVersion: Int(Date.now.timeIntervalSince1970 * 1_000),
            ]
        )
        try await store.save(sample)
    }

    // MARK: Workouts

    /// Strength training, or an indoor walk with its distance. Health knows only the total pause, so it is written as
    /// one pause right before the end: the workout's duration comes out right, its start and end stay the real ones.
    func saveWorkout(_ workout: HealthWorkout) async throws -> UUID {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = workout.isWalk ? .walking : .traditionalStrengthTraining
        configuration.locationType = .indoor
        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        try await builder.beginCollection(at: workout.start)
        if workout.pausedDuration > 0 {
            let pauseStart = max(workout.start, workout.end.addingTimeInterval(-workout.pausedDuration))
            try await builder.addWorkoutEvents([
                HKWorkoutEvent(type: .pause, dateInterval: DateInterval(start: pauseStart, duration: 0), metadata: nil),
                HKWorkoutEvent(
                    type: .resume, dateInterval: DateInterval(start: workout.end, duration: 0), metadata: nil),
            ])
        }
        if let distanceKm = workout.distanceKm, distanceKm > 0 {
            try await builder.addSamples([
                HKQuantitySample(
                    type: HKQuantityType(.distanceWalkingRunning),
                    quantity: HKQuantity(unit: .meterUnit(with: .kilo), doubleValue: distanceKm),
                    start: workout.start,
                    end: workout.end
                )
            ])
        }
        try await builder.endCollection(at: workout.end)
        guard let saved = try await builder.finishWorkout() else { throw HealthWorkoutError.notSaved }
        return saved.uuid
    }

    /// Health lets an app delete only what it saved itself, which is all Peak asks for. Already gone is fine.
    func deleteWorkout(id: UUID) async throws {
        _ = try await store.deleteObjects(of: .workoutType(), predicate: HKQuery.predicateForObject(with: id))
    }

    // MARK: Helpers

    /// One value per day from `from` to `to`, keyed by the day's start.
    private func dailyStatistics(
        _ identifier: HKQuantityTypeIdentifier,
        options: HKStatisticsOptions,
        from: Date,
        to end: Date,
        value: (HKStatistics) -> Double?
    ) async throws -> [Date: Double] {
        let type = HKQuantityType(identifier)
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: HKQuery.predicateForSamples(withStart: from, end: end)),
            options: options,
            anchorDate: from,
            intervalComponents: DateComponents(day: 1)
        )
        let collection = try await descriptor.result(for: store)
        var result: [Date: Double] = [:]
        for statistics in collection.statistics() {
            if let amount = value(statistics) {
                result[statistics.startDate] = amount
            }
        }
        return result
    }
}

enum HealthWorkoutError: Error {
    /// HealthKit finished the builder without returning a workout.
    case notSaved
}
