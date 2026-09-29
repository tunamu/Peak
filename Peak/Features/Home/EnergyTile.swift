import PeakCore
import PeakDesign
import SwiftUI

/// C-05: today's energy level. Tap for the reasons (S-08). Only today has a score.
struct EnergyTile: View {
    /// `nil` on other days than today.
    let result: EnergyResult?

    @State private var isDetailShown = false

    var body: some View {
        Button {
            isDetailShown = true
        } label: {
            VStack(spacing: Spacing.xSmall) {
                Image(systemName: "bolt.fill")
                    .font(.largeTitle)
                    .foregroundStyle(result.map { $0.level.color } ?? .peakTextTertiary)
                    .accessibilityHidden(true)
                VStack(spacing: 2) {
                    Text("Energy Level")
                        .font(.peakCardLabel)
                        .foregroundStyle(.peakTextSecondary)
                    (result.map { $0.level.title } ?? Text(verbatim: "–"))
                        .font(.peakCardValue)
                        .foregroundStyle(.peakTextPrimary)
                    (result.map { $0.level.shortMessage } ?? Text("Only for today"))
                        .font(.peakDetail)
                        .foregroundStyle(.peakTextTertiary)
                }
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .glassCard()
            .contentShape(.rect(cornerRadius: Radius.card))
        }
        .buttonStyle(.plain)
        .disabled(result == nil)
        .accessibilityElement(children: .combine)
        .sheet(isPresented: $isDetailShown) {
            if let result {
                EnergySheet(result: result)
            }
        }
    }
}

/// S-08: the level, why points were taken off, and which data was used.
struct EnergySheet: View {
    let result: EnergyResult

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: Spacing.large) {
            VStack(spacing: Spacing.xxSmall) {
                Image(systemName: "bolt.fill")
                    .font(.largeTitle)
                    .foregroundStyle(result.level.color)
                    .accessibilityHidden(true)
                Text("Energy Level")
                    .font(.peakCardLabel)
                    .foregroundStyle(.peakTextSecondary)
                result.level.title
                    .font(.peakCardValue)
                    .foregroundStyle(.peakTextPrimary)
                result.level.message
                    .font(.peakDetail)
                    .foregroundStyle(.peakTextTertiary)
            }
            .multilineTextAlignment(.center)
            .accessibilityElement(children: .combine)

            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                Text("Why")
                    .font(.peakRow)
                    .foregroundStyle(.peakTextSecondary)
                if result.reasons.isEmpty {
                    Text("Nothing is holding you back today.")
                        .font(.peakRow)
                        .foregroundStyle(.peakTextPrimary)
                }
                ForEach(Array(result.reasons.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline) {
                        item.reason.text
                            .foregroundStyle(.peakTextPrimary)
                        Spacer(minLength: Spacing.small)
                        Text(verbatim: "−\(item.points)")
                            .monospacedDigit()
                            .foregroundStyle(.peakTextTertiary)
                    }
                    .font(.peakRow)
                    .accessibilityElement(children: .combine)
                }

                Text("Data")
                    .font(.peakRow)
                    .foregroundStyle(.peakTextSecondary)
                    .padding(.top, Spacing.small)
                sourceRow(Text("Workouts"), used: true, from: Text(verbatim: "Peak"))
                sourceRow(Text("Sleep"), used: result.sources.contains(.sleep), from: Text("Apple Health"))
                sourceRow(Text("Heart rate"), used: result.sources.contains(.heart), from: Text("Apple Watch"))

                Text("Not medical advice.")
                    .font(.peakDetail)
                    .foregroundStyle(.peakTextTertiary)
                    .padding(.top, Spacing.small)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassTable()

            Button(role: .confirm) {
                dismiss()
            } label: {
                Text("Done").frame(maxWidth: .infinity)
            }
            .buttonStyle(.peakGlass)
        }
        .padding(Spacing.large)
        .fittedSheet()
    }

    private func sourceRow(_ title: Text, used: Bool, from source: Text) -> some View {
        HStack {
            title.foregroundStyle(.peakTextPrimary)
            Spacer()
            (used ? source : Text("No data"))
                .foregroundStyle(.peakTextTertiary)
        }
        .font(.peakRow)
        .accessibilityElement(children: .combine)
    }
}

extension EnergyLevel {
    var title: Text {
        switch self {
        case .ready: Text("Ready")
        case .low: Text("Low")
        case .notReady: Text("Not Ready")
        }
    }

    /// The tile's one line.
    var shortMessage: Text {
        switch self {
        case .ready: Text("You can workout now")
        case .low: Text("You can workout a bit")
        case .notReady: Text("You can't workout now")
        }
    }

    /// The detail sheet's message.
    var message: Text {
        switch self {
        case .notReady: Text("You can't workout now. You should rest at least 1 day to workout again.")
        default: shortMessage
        }
    }

    var color: Color {
        switch self {
        case .ready: .peakEnergyReady
        case .low: .peakEnergyLow
        case .notReady: .peakEnergyNotReady
        }
    }
}

extension EnergyReason {
    /// A sentence for the detail sheet, such as "Last workout 18 hours ago".
    var text: Text {
        switch self {
        case .lastWorkout(let hours):
            return Text("Last workout \(hours) hours ago")
        case .sameMuscles(let groups):
            let names = groups.map { String(localized: $0.title) }.formatted(.list(type: .and))
            return Text("Trained in the last 2 days: \(names)")
        case .trainingStreak(let days):
            return Text("\(days) training days in a row")
        case .sleep(let duration):
            let time = Duration.seconds(duration).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
            return Text("Slept \(time)")
        case .heartRateVariability(let percent):
            return Text("Heart rate variability \(abs(percent))% below average")
        case .restingHeartRate(let bpm):
            return Text("Resting heart rate \(bpm) bpm above average")
        }
    }
}

#if DEBUG
    #Preview("Tiles") {
        let engine = EnergyEngine()
        let now = Date.now
        let workout = EnergyInput.Workout(endedAt: now.addingTimeInterval(-18 * 3_600), muscleGroups: [.chest])
        GlassEffectContainer {
            VStack(spacing: Spacing.medium) {
                HStack(spacing: Spacing.medium) {
                    EnergyTile(result: engine.evaluate(EnergyInput(now: now)))
                    EnergyTile(result: engine.evaluate(EnergyInput(now: now, workouts: [workout])))
                }
                HStack(spacing: Spacing.medium) {
                    EnergyTile(
                        result: engine.evaluate(
                            EnergyInput(now: now, workouts: [workout], plannedMuscleGroups: [.chest])
                                .with(EnergySignals(sleepDuration: 4.5 * 3_600))))
                    EnergyTile(result: nil)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(.peakCanvas)
    }

    #Preview("Sheet") {
        let input = EnergyInput(
            now: .now,
            workouts: [.init(endedAt: .now.addingTimeInterval(-18 * 3_600), muscleGroups: [.chest, .biceps])],
            plannedMuscleGroups: [.chest]
        ).with(EnergySignals(sleepDuration: 5.5 * 3_600))
        Color.peakCanvas.sheet(isPresented: .constant(true)) {
            EnergySheet(result: EnergyEngine().evaluate(input))
        }
    }
#endif
