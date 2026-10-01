import PeakCore
import PeakDesign
import SwiftUI

/// F11-05: one workout template over time: volume, completion, targets hit and duration, and every session of it.
struct WorkoutDetailView: View {
    enum Metric: CaseIterable, Hashable {
        case volume, completion, targetsHit, duration
    }

    let workout: WorkoutSeries
    /// Opens a session read-only.
    let open: (UUID) -> Void

    @Environment(SettingsStore.self) private var settings
    @State private var metric = Metric.volume

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                    HStack(spacing: Spacing.xSmall) {
                        Text(verbatim: workout.title)
                            .font(.peakScreenTitle.weight(.semibold))
                            .foregroundStyle(.peakTextPrimary)
                            .accessibilityAddTraits(.isHeader)
                        TrendArrow(trend: workout.trend)
                    }
                    Text("\(workout.points.count) Workouts")
                        .font(.peakRow)
                        .foregroundStyle(.peakTextSecondary)
                }
                VStack(alignment: .leading, spacing: Spacing.small) {
                    Picker("Measure", selection: $metric) {
                        ForEach(Metric.allCases, id: \.self) { metric in
                            Text(title(of: metric)).tag(metric)
                        }
                    }
                    .pickerStyle(.segmented)
                    ProgressChart(
                        points: workout.points.compactMap { point in
                            shown(point).map {
                                .init(id: point.sessionID, date: point.date, value: $0, text: format(point, metric))
                            }
                        },
                        label: Text(title(of: metric))
                    )
                }
                .glassCard()
                sessionList
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.vertical, Spacing.medium)
        }
        .background(.peakCanvas)
        .navigationTitle(Text(verbatim: workout.title))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarVisibility(.visible, for: .navigationBar)
        .toolbar {
            // The name is the page's own title below; the bar keeps only the back button.
            ToolbarItem(placement: .principal) {
                Color.clear.frame(width: 1, height: 1).accessibilityHidden(true)
            }
        }
        .peakHaptic(.selection, trigger: metric)
    }

    private var unit: UnitSystem { settings.unitSystem }

    private var sessionList: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            SectionHeader("Sessions")
            VStack(spacing: 0) {
                ForEach(workout.points.reversed(), id: \.sessionID) { point in
                    Button {
                        open(point.sessionID)
                    } label: {
                        HStack(spacing: Spacing.xSmall) {
                            Text(point.date, format: .dateTime.weekday(.abbreviated).day().month())
                                .foregroundStyle(.peakTextPrimary)
                            Spacer(minLength: Spacing.xSmall)
                            Text(
                                verbatim: [
                                    Formatting.weight(point.volumeKg, unit: unit, fractionLength: 0),
                                    Formatting.percent(point.completion),
                                    Formatting.duration(point.duration),
                                ].joined(separator: " · ")
                            )
                            .monospacedDigit()
                            .foregroundStyle(.peakTextSecondary)
                        }
                        .font(.peakRow)
                        .padding(.horizontal, Spacing.xSmall)
                        .frame(minHeight: Metrics.minTouchTarget)
                        .contentShape(.rect)
                        .accessibilityElement(children: .combine)
                        .accessibilityHint(Text("Opens the workout"))
                    }
                    .buttonStyle(.plain)
                }
            }
            .glassTable()
        }
    }

    private func title(of metric: Metric) -> LocalizedStringKey {
        switch metric {
        case .volume: "Volume"
        case .completion: "Completed"
        case .targetsHit: "Targets Hit"
        case .duration: "Duration"
        }
    }

    /// The value as the chart plots it: weights in the user's unit, shares in percent, durations in minutes.
    /// `nil` leaves the session off the chart: targets hit of a session without targets (imported).
    private func shown(_ point: WorkoutPoint) -> Double? {
        switch metric {
        case .volume: WeightUnits.displayValue(kg: point.volumeKg, in: unit)
        case .completion: point.completion * 100
        case .targetsHit: point.successRate.map { $0 * 100 }
        case .duration: point.duration / 60
        }
    }

    private func format(_ point: WorkoutPoint, _ metric: Metric) -> String {
        switch metric {
        case .volume: Formatting.weight(point.volumeKg, unit: unit, fractionLength: 0)
        case .completion: Formatting.percent(point.completion)
        case .targetsHit: point.successRate.map(Formatting.percent) ?? "–"
        case .duration: Formatting.duration(point.duration)
        }
    }
}
