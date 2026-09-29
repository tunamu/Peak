import Foundation
import Observation

public enum UnitSystem: String, CaseIterable, Codable, Sendable {
    case metric, imperial
}

/// Somewhere settings are copied to and read back from, such as iCloud's key-value store (F8).
public protocol SettingsMirror: AnyObject {
    func value(forKey key: String) -> Any?
    func set(_ value: Any?, forKey key: String)
    /// Called on the main actor when the mirror changes from outside (another device), with the changed keys.
    /// Implementations hop to the main actor first; iCloud's notification arrives on a background queue.
    var onExternalChange: (@MainActor ([String]) -> Void)? { get set }
}

/// App settings (docs/DATA_MODEL.md › Settings). Stored in the App Group's `UserDefaults` so the widget can read
/// them, and copied to an optional mirror for sync between devices.
///
/// Values are clamped to the ranges the pickers offer, so a bad import or a stale mirror cannot store nonsense.
@MainActor
@Observable
public final class SettingsStore {
    public enum Key: String, CaseIterable {
        case stepGoal, waterGoalMl, overloadThresholdReps, overloadResetReps, unitSystem, quickWaterAmounts
        case hasCompletedOnboarding
    }

    public enum Defaults {
        public static let stepGoal = 10_000
        public static let waterGoalMl = 4_000
        public static let overloadThresholdReps = 12
        public static let overloadResetReps = 6
        public static let quickWaterAmounts = [200, 330, 500, 1_000]
    }

    public enum Limits {
        public static let stepGoal = 1_000...50_000
        public static let waterGoalMl = 1_000...6_000
        public static let overloadReps = 6...20
        public static let quickWaterAmount = 50...2_000
    }

    public var stepGoal: Int {
        didSet { store(\.stepGoal, clamped: stepGoal.clamped(to: Limits.stepGoal), key: .stepGoal) }
    }
    public var waterGoalMl: Int {
        didSet { store(\.waterGoalMl, clamped: waterGoalMl.clamped(to: Limits.waterGoalMl), key: .waterGoalMl) }
    }
    /// Reps a set must exceed before its weight goes up (">12").
    public var overloadThresholdReps: Int {
        didSet {
            store(
                \.overloadThresholdReps, clamped: overloadThresholdReps.clamped(to: Limits.overloadReps),
                key: .overloadThresholdReps
            )
        }
    }
    /// The rep target after a weight increase.
    public var overloadResetReps: Int {
        didSet {
            store(
                \.overloadResetReps, clamped: overloadResetReps.clamped(to: Limits.overloadReps),
                key: .overloadResetReps
            )
        }
    }
    public var unitSystem: UnitSystem {
        didSet { write(unitSystem.rawValue, for: .unitSystem) }
    }
    /// The water sheet's slider stops, in ml.
    public var quickWaterAmounts: [Int] {
        didSet {
            store(
                \.quickWaterAmounts, clamped: Self.validQuickAmounts(quickWaterAmounts), key: .quickWaterAmounts
            )
        }
    }
    public var hasCompletedOnboarding: Bool {
        didSet { write(hasCompletedOnboarding, for: .hasCompletedOnboarding) }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let mirror: SettingsMirror?

    /// - Parameters:
    ///   - defaults: The App Group's defaults in the app; a throwaway suite in tests.
    ///   - mirror: A sync mirror. When given, its values win at start-up and on external changes.
    public init(defaults: UserDefaults, mirror: SettingsMirror? = nil) {
        self.defaults = defaults
        self.mirror = mirror
        let snapshot = Snapshot { mirror?.value(forKey: $0.rawValue) ?? defaults.object(forKey: $0.rawValue) }
        stepGoal = snapshot.stepGoal
        waterGoalMl = snapshot.waterGoalMl
        overloadThresholdReps = snapshot.overloadThresholdReps
        overloadResetReps = snapshot.overloadResetReps
        unitSystem = snapshot.unitSystem
        quickWaterAmounts = snapshot.quickWaterAmounts
        hasCompletedOnboarding = snapshot.hasCompletedOnboarding
        mirror?.onExternalChange = { [weak self] keys in
            self?.reload(keys)
        }
    }

    /// The App Group store, shared with the widget. Falls back to the app's own defaults if the group is missing
    /// (an unsigned build).
    public static func appGroupDefaults() -> UserDefaults {
        UserDefaults(suiteName: PeakStore.appGroupID) ?? .standard
    }

    /// Restores every setting to its default (onboarding state is kept).
    public func resetToDefaults() {
        stepGoal = Defaults.stepGoal
        waterGoalMl = Defaults.waterGoalMl
        overloadThresholdReps = Defaults.overloadThresholdReps
        overloadResetReps = Defaults.overloadResetReps
        unitSystem = .metric
        quickWaterAmounts = Defaults.quickWaterAmounts
    }

    // MARK: Private

    /// Writes the clamped value back if clamping changed it (which re-enters `didSet` once), otherwise persists.
    private func store<Value: Equatable>(
        _ keyPath: ReferenceWritableKeyPath<SettingsStore, Value>,
        clamped: Value,
        key: Key
    ) {
        if self[keyPath: keyPath] != clamped {
            self[keyPath: keyPath] = clamped
        } else {
            write(clamped, for: key)
        }
    }

    private func write(_ value: Any, for key: Key) {
        defaults.set(value, forKey: key.rawValue)
        mirror?.set(value, forKey: key.rawValue)
    }

    /// Re-reads everything from the mirror when a setting changed on another device.
    private func reload(_ keys: [String]) {
        guard let mirror, keys.contains(where: { Key(rawValue: $0) != nil }) else { return }
        let fresh = Snapshot { mirror.value(forKey: $0.rawValue) ?? defaults.object(forKey: $0.rawValue) }
        // Assign only what changed, so unchanged values are not written back.
        if stepGoal != fresh.stepGoal { stepGoal = fresh.stepGoal }
        if waterGoalMl != fresh.waterGoalMl { waterGoalMl = fresh.waterGoalMl }
        if overloadThresholdReps != fresh.overloadThresholdReps { overloadThresholdReps = fresh.overloadThresholdReps }
        if overloadResetReps != fresh.overloadResetReps { overloadResetReps = fresh.overloadResetReps }
        if unitSystem != fresh.unitSystem { unitSystem = fresh.unitSystem }
        if quickWaterAmounts != fresh.quickWaterAmounts { quickWaterAmounts = fresh.quickWaterAmounts }
        if hasCompletedOnboarding != fresh.hasCompletedOnboarding {
            hasCompletedOnboarding = fresh.hasCompletedOnboarding
        }
    }

    /// Every setting read from a source, with defaults for missing values and ranges applied.
    private struct Snapshot {
        let stepGoal: Int
        let waterGoalMl: Int
        let overloadThresholdReps: Int
        let overloadResetReps: Int
        let unitSystem: UnitSystem
        let quickWaterAmounts: [Int]
        let hasCompletedOnboarding: Bool

        init(_ read: (Key) -> Any?) {
            stepGoal = ((read(.stepGoal) as? Int) ?? Defaults.stepGoal).clamped(to: Limits.stepGoal)
            waterGoalMl = ((read(.waterGoalMl) as? Int) ?? Defaults.waterGoalMl).clamped(to: Limits.waterGoalMl)
            overloadThresholdReps = ((read(.overloadThresholdReps) as? Int) ?? Defaults.overloadThresholdReps)
                .clamped(to: Limits.overloadReps)
            overloadResetReps = ((read(.overloadResetReps) as? Int) ?? Defaults.overloadResetReps)
                .clamped(to: Limits.overloadReps)
            unitSystem = (read(.unitSystem) as? String).flatMap(UnitSystem.init(rawValue:)) ?? .metric
            quickWaterAmounts = SettingsStore.validQuickAmounts(
                (read(.quickWaterAmounts) as? [Int]) ?? Defaults.quickWaterAmounts
            )
            hasCompletedOnboarding = (read(.hasCompletedOnboarding) as? Bool) ?? false
        }
    }

    private nonisolated static func validQuickAmounts(_ amounts: [Int]) -> [Int] {
        let valid = Array(Set(amounts.map { $0.clamped(to: Limits.quickWaterAmount) })).sorted()
        return valid.isEmpty ? Defaults.quickWaterAmounts : Array(valid.prefix(4))
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

extension SettingsStore {
    /// The overload rule the user set (S-04), for new targets.
    public var progressionRule: ProgressionRule {
        ProgressionRule(thresholdReps: overloadThresholdReps, resetReps: overloadResetReps)
    }
}
