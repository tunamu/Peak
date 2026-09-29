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

    @Test func mirrorGetsWritesAndWinsOnStart() throws {
        let mirror = FakeMirror()
        let defaults = try makeDefaults()
        SettingsStore(defaults: defaults, mirror: mirror).waterGoalMl = 3_000
        #expect(mirror.values["waterGoalMl"] as? Int == 3_000)

        mirror.values["waterGoalMl"] = 5_000
        #expect(SettingsStore(defaults: defaults, mirror: mirror).waterGoalMl == 5_000)
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
