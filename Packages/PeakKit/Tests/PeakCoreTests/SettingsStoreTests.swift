import Foundation
import PeakCore
import Testing

/// A stand-in for iCloud's key-value store.
final class FakeMirror: SettingsMirror {
    var values: [String: Any] = [:]
    var onExternalChange: (@MainActor ([String]) -> Void)?

    func value(forKey key: String) -> Any? { values[key] }
    func set(_ value: Any?, forKey key: String) { values[key] = value }
}

@MainActor
@Suite struct SettingsStoreTests {
    /// A throwaway defaults suite per test.
    func makeDefaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: "peak.tests.\(UUID().uuidString)"))
    }

    @Test func startsWithDefaults() throws {
        let settings = SettingsStore(defaults: try makeDefaults())
        #expect(settings.stepGoal == 10_000)
        #expect(settings.waterGoalMl == 4_000)
        #expect(settings.overloadThresholdReps == 12)
        #expect(settings.overloadResetReps == 6)
        #expect(settings.overloadRepStep == 1)
        #expect(settings.unitSystem == .metric)
        #expect(settings.quickWaterAmounts == [200, 330, 500, 1_000])
        #expect(!settings.hasCompletedOnboarding)
    }

    @Test func changesAreWrittenForTheWidget() throws {
        let defaults = try makeDefaults()
        let settings = SettingsStore(defaults: defaults)
        settings.stepGoal = 12_500
        settings.unitSystem = .imperial
        #expect(defaults.integer(forKey: "stepGoal") == 12_500)
        #expect(defaults.string(forKey: "unitSystem") == "imperial")
        #expect(SettingsStore(defaults: defaults).stepGoal == 12_500)
    }

    @Test func valuesAreClampedToThePickerRanges() throws {
        let defaults = try makeDefaults()
        let settings = SettingsStore(defaults: defaults)
        settings.stepGoal = 999_999
        settings.overloadThresholdReps = 2
        settings.quickWaterAmounts = [500, 10, 500, 5_000, 330, 250]
        #expect(settings.stepGoal == 50_000)
        #expect(defaults.integer(forKey: "stepGoal") == 50_000)
        #expect(settings.overloadThresholdReps == 6)
        #expect(settings.quickWaterAmounts == [50, 250, 330, 500])

        defaults.set(-4, forKey: "waterGoalMl")
        #expect(SettingsStore(defaults: defaults).waterGoalMl == 1_000)
    }

    /// The Rep Increase row: 0…5, and the targets follow it (50×9 → 50×11 with 2).
    @Test func theRepIncreaseIsClampedAndReachesTheRule() throws {
        let settings = SettingsStore(defaults: try makeDefaults())
        settings.overloadRepStep = 9
        #expect(settings.overloadRepStep == 5)
        settings.overloadRepStep = -1
        #expect(settings.overloadRepStep == 0)

        settings.overloadRepStep = 2
        let target = ProgressionEngine.target(
            after: SetPerformance(weightKg: 50, reps: 9), incrementKg: 5, rule: settings.progressionRule)
        #expect(target == SetTarget(weightKg: 50, reps: 11))
        // Above the threshold the weight still goes up and the reps reset.
        let increase = ProgressionEngine.target(
            after: SetPerformance(weightKg: 50, reps: 13), incrementKg: 5, rule: settings.progressionRule)
        #expect(increase == SetTarget(weightKg: 55, reps: 6))

        settings.resetToDefaults()
        #expect(settings.overloadRepStep == 1)
    }

    @Test func mirrorGetsWritesAndWinsOnStart() throws {
        let mirror = FakeMirror()
        let defaults = try makeDefaults()
        SettingsStore(defaults: defaults, mirror: mirror).waterGoalMl = 3_000
        #expect(mirror.values["waterGoalMl"] as? Int == 3_000)

        mirror.values["waterGoalMl"] = 5_000
        #expect(SettingsStore(defaults: defaults, mirror: mirror).waterGoalMl == 5_000)
    }

    @Test func startReconcilesDefaultsAndMirror() throws {
        let mirror = FakeMirror()
        let defaults = try makeDefaults()
        mirror.values["stepGoal"] = 99_000  // from another device, clamped on the way in
        defaults.set(2_500, forKey: "waterGoalMl")  // only this device has it
        _ = SettingsStore(defaults: defaults, mirror: mirror)

        // The widget reads the App Group copy, so the mirror's value lands there.
        #expect(defaults.integer(forKey: "stepGoal") == 50_000)
        #expect(mirror.values["waterGoalMl"] as? Int == 2_500)
        // Neither side had it: nothing is pushed, so a new device cannot overwrite values still downloading.
        #expect(mirror.values["unitSystem"] == nil)
        #expect(defaults.object(forKey: "unitSystem") == nil)
    }

    /// Turning iCloud sync on later: the mirror is reconciled like at start-up and then follows changes.
    @Test func aMirrorAttachedLaterIsReconciledAndFollowed() throws {
        let defaults = try makeDefaults()
        let settings = SettingsStore(defaults: defaults)
        settings.waterGoalMl = 2_500
        let mirror = FakeMirror()
        mirror.values["stepGoal"] = 8_000

        settings.setMirror(mirror)
        #expect(settings.stepGoal == 8_000)
        #expect(defaults.integer(forKey: "stepGoal") == 8_000)
        #expect(mirror.values["waterGoalMl"] as? Int == 2_500)

        settings.overloadResetReps = 8
        #expect(mirror.values["overloadResetReps"] as? Int == 8)

        // Turned off: changes stay on the device, and the old mirror no longer reaches the store.
        settings.setMirror(nil)
        settings.overloadResetReps = 9
        #expect(mirror.values["overloadResetReps"] as? Int == 8)
        #expect(mirror.onExternalChange == nil)
    }

    @Test func externalMirrorChangeUpdatesTheStore() throws {
        let mirror = FakeMirror()
        let defaults = try makeDefaults()
        let settings = SettingsStore(defaults: defaults, mirror: mirror)
        mirror.values["stepGoal"] = 8_000
        mirror.onExternalChange?(["stepGoal", "unknownKey"])
        #expect(settings.stepGoal == 8_000)
        #expect(defaults.integer(forKey: "stepGoal") == 8_000)
    }

    @Test func resetKeepsOnboardingState() throws {
        let settings = SettingsStore(defaults: try makeDefaults())
        settings.hasCompletedOnboarding = true
        settings.stepGoal = 20_000
        settings.resetToDefaults()
        #expect(settings.stepGoal == 10_000)
        #expect(settings.hasCompletedOnboarding)
    }
}
