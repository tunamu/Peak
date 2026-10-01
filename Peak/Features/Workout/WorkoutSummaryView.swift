import PeakCore
import PeakDesign
import SwiftUI

/// S-11: the finished workout. Duration, volume and targets hit, the walk's distance, and the weights that go up next
/// time (↑). A variant of the result sheet (S-09).
struct WorkoutSummaryView: View {
    let summary: WorkoutSummary
    let unit: UnitSystem
    let done: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 52
    @State private var isShown = false

    var body: some View {
        VStack(spacing: Spacing.large) {
            Image(systemName: "checkmark")
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(.peakEnergyReady)
                .accessibilityHidden(true)

            VStack(spacing: Spacing.xxSmall) {
                Text("Workout Complete")
                    .font(.peakCardLabel)
                    .foregroundStyle(.peakTextSecondary)
                Text(verbatim: summary.title)
                    .font(.peakEmphasis)
                    .foregroundStyle(.peakTextPrimary)
            }
            .accessibilityElement(children: .combine)

            HStack(alignment: .top, spacing: Spacing.medium) {
                stat("Duration", value: duration)
                if summary.volumeKg > 0 {
                    stat("Volume", value: weight(summary.volumeKg, fractionLength: 0))
                }
                if let distanceKm = summary.distanceKm {
                    stat("Distance", value: "\(distanceKm.formatted(.number.precision(.fractionLength(0...2)))) km")
                } else {
                    stat("Targets Hit", value: summary.successRate.formatted(.percent.precision(.fractionLength(0))))
                }
            }

            if !summary.risingTargets.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    Text("Next Time")
                        .font(.peakDetail)
                        .foregroundStyle(.peakTextSecondary)
                    ForEach(summary.risingTargets, id: \.self) { target in
                        HStack(spacing: Spacing.xSmall) {
                            Image(systemName: "arrow.up")
                                .foregroundStyle(.peakEnergyReady)
                                .accessibilityHidden(true)
                            Text(verbatim: target.name)
                                .foregroundStyle(.peakTextPrimary)
                                .lineLimit(1)
                            Spacer(minLength: Spacing.xSmall)
                            Text(verbatim: "\(weight(target.fromKg)) → \(weight(target.toKg))")
                                .monospacedDigit()
                                .foregroundStyle(.peakTextSecondary)
                        }
                        .font(.peakRow)
                        .accessibilityElement(children: .combine)
                    }
                }
                .glassTable()
            }

            Button(action: done) {
                Text("Done").frame(maxWidth: .infinity)
            }
            .buttonStyle(.peakGlass)
        }
        .padding(Spacing.large)
        .onAppear { isShown = true }
        .peakHaptic(.success, trigger: isShown)
        .fittedSheet()
    }

    private func stat(_ title: LocalizedStringKey, value: String) -> some View {
        VStack(spacing: Spacing.xxSmall) {
            Text(title)
                .font(.peakDetail)
                .foregroundStyle(.peakTextSecondary)
            Text(verbatim: value)
                .font(.peakCardValue)
                .monospacedDigit()
                .foregroundStyle(.peakTextPrimary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    /// "42 min", or "1 hr 5 min".
    private var duration: String {
        Duration.seconds(summary.duration).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    private func weight(_ kg: Double, fractionLength: Int = 2) -> String {
        let value = WeightUnits.displayValue(kg: kg, in: unit).formatted(
            .number.precision(.fractionLength(0...fractionLength)))
        return "\(value) \(unit == .metric ? "kg" : "lb")"
    }
}

#if DEBUG
    #Preview {
        Color.clear.sheet(isPresented: .constant(true)) {
            WorkoutSummaryView(
                summary: WorkoutSummary(
                    title: "Chest & Biceps",
                    duration: 42 * 60,
                    volumeKg: 4_310,
                    successRate: 0.8,
                    completion: 1,
                    risingTargets: [.init(name: "Dumbbell Chest Press", fromKg: 27.5, toKg: 30)]
                ),
                unit: .metric
            ) {}
        }
    }
#endif
