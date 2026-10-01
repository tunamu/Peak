import PeakCore
import PeakDesign
import SwiftUI

/// F11-10: a workout's or a movement's own progressive overload. Off, it follows `base` (Settings, or the workout's
/// own for a movement); on, it starts from `base` and each value can change.
struct OverloadOverrideSection: View {
    @Binding var override: OverloadOverride
    /// What applies without an own rule.
    let base: ProgressionRule
    /// "Settings" or "the workout", in the footer.
    let footer: LocalizedStringKey

    var body: some View {
        Section {
            Toggle("Own Rule", isOn: isOn)
            if isOn.wrappedValue {
                Stepper(value: value(\.thresholdReps, base.thresholdReps), in: SettingsStore.Limits.overloadReps) {
                    row("Weight Up Above", value: ">\(override.thresholdReps ?? base.thresholdReps)")
                }
                Stepper(value: value(\.resetReps, base.resetReps), in: SettingsStore.Limits.overloadReps) {
                    row("Reps After Weight Up", value: "\(override.resetReps ?? base.resetReps)")
                }
                Stepper(value: value(\.repStep, base.repStep), in: SettingsStore.Limits.overloadRepStep) {
                    row("Rep Increase", value: "+\(override.repStep ?? base.repStep)")
                }
            }
        } header: {
            Text("Progressive Overload")
        } footer: {
            Text(footer)
        }
    }

    private var isOn: Binding<Bool> {
        Binding {
            !override.isEmpty
        } set: { isOn in
            override =
                isOn
                ? OverloadOverride(thresholdReps: base.thresholdReps, resetReps: base.resetReps, repStep: base.repStep)
                : OverloadOverride()
        }
    }

    private func value(_ keyPath: WritableKeyPath<OverloadOverride, Int?>, _ fallback: Int) -> Binding<Int> {
        Binding {
            override[keyPath: keyPath] ?? fallback
        } set: {
            override[keyPath: keyPath] = $0
        }
    }

    private func row(_ title: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(verbatim: value)
                .monospacedDigit()
                .foregroundStyle(.peakTextSecondary)
        }
    }
}
