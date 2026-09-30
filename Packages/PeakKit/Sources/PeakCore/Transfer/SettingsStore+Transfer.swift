import Foundation

extension SettingsStore {
    /// The settings as Peak JSON writes them.
    public var transferSettings: PeakExportV1.Settings {
        PeakExportV1.Settings(
            stepGoal: stepGoal, waterGoalMl: waterGoalMl,
            overload: .init(thresholdReps: overloadThresholdReps, resetReps: overloadResetReps),
            unitSystem: unitSystem, quickWaterAmounts: quickWaterAmounts
        )
    }

    /// Takes the values a file has; missing ones stay as they are, and each is clamped like any other change.
    public func apply(_ settings: PeakExportV1.Settings) {
        if let value = settings.stepGoal { stepGoal = value }
        if let value = settings.waterGoalMl { waterGoalMl = value }
        if let value = settings.overload?.thresholdReps { overloadThresholdReps = value }
        if let value = settings.overload?.resetReps { overloadResetReps = value }
        if let value = settings.unitSystem { unitSystem = value }
        if let value = settings.quickWaterAmounts { quickWaterAmounts = value }
    }
}
