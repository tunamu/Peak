import PeakCore
import PeakDesign
import SwiftData
import SwiftUI

/// F11-05: one movement over time. A chart of the chosen measure, its record and trend, and every session it was
/// done in, each opening that workout.
struct MovementDetailView: View {
    enum Metric: Hashable {
        case oneRepMax, weight, reps, volume, sets, distance, minutes
    }

    let movement: MovementSummary
    /// Opens a session read-only.
    let open: (UUID) -> Void

    @Environment(SettingsStore.self) private var settings
    @Query private var exercises: [Exercise]
    @State private var metric: Metric?
    @State private var isSettingsShown = false

    var body: some View {
        let metric = metric ?? metrics.first ?? .reps
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                header
                VStack(alignment: .leading, spacing: Spacing.small) {
                    if metrics.count > 1 {
                        Picker("Measure", selection: Binding(get: { metric }, set: { self.metric = $0 })) {
                            ForEach(metrics, id: \.self) { metric in
                                Text(title(of: metric)).tag(metric)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    ProgressChart(
                        points: movement.points.compactMap { point in
                            value(of: point, metric).map {
                                .init(
                                    id: point.sessionID, date: point.date, value: shown($0, metric),
                                    text: format($0, metric), isRecord: metric == mainMetric && point.isRecord)
                            }
                        },
                        label: Text(title(of: metric))
                    )
                    if metric == .oneRepMax {
                        Text("Estimated from each session's best set (weight × (1 + reps ÷ 30)).")
                            .font(.peakDetail)
                            .foregroundStyle(.peakTextTertiary)
                    }
                }
                .glassCard()
                notes
                sessionList
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.screenMargin)
            .padding(.vertical, Spacing.medium)
        }
        .background(.peakCanvas)
        .navigationTitle(Text(verbatim: movement.name))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarVisibility(.visible, for: .navigationBar)
        .toolbar {
            // The name is the page's own title below; the bar keeps only the back button.
            ToolbarItem(placement: .principal) {
                Color.clear.frame(width: 1, height: 1).accessibilityHidden(true)
            }
        }
        .peakHaptic(.selection, trigger: metric)
        .toolbar {
            if exercise != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Movement Settings", systemImage: "slider.horizontal.3") { isSettingsShown = true }
                }
            }
        }
        .sheet(isPresented: $isSettingsShown) {
            if let exercise {
                MovementSettingsSheet(exercise: exercise)
            }
        }
    }

    private var unit: UnitSystem { settings.unitSystem }

    /// The movement in the library, for its settings; `nil` when only sessions remember it.
    private var exercise: Exercise? {
        exercises.first { $0.name.matchingKey == movement.key }
    }

    // MARK: Notes

    /// F11-12: how it is set up, and what was noted session by session.
    @ViewBuilder
    private var notes: some View {
        let setup = exercise?.note ?? movement.setupNote
        if !setup.isEmpty || !movement.notes.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.small) {
                SectionHeader("Notes")
                VStack(alignment: .leading, spacing: Spacing.small) {
                    if !setup.isEmpty {
                        Label {
                            Text(verbatim: setup)
                        } icon: {
                            Image(systemName: "pin.fill")
                                .accessibilityLabel(Text("Setup"))
                        }
                        .foregroundStyle(.peakTextPrimary)
                    }
                    ForEach(movement.notes, id: \.sessionID) { point in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(point.date, format: .dateTime.day().month().year())
                                .font(.peakDetail)
                                .foregroundStyle(.peakTextSecondary)
                            Text(verbatim: point.note)
                                .foregroundStyle(.peakTextPrimary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .font(.peakRow)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            Text(movement.muscleGroup.title)
                .font(.peakDetail)
                .foregroundStyle(.peakTextSecondary)
            HStack(spacing: Spacing.xSmall) {
                Text(verbatim: movement.name)
                    .font(.peakScreenTitle.weight(.semibold))
                    .foregroundStyle(.peakTextPrimary)
                    .accessibilityAddTraits(.isHeader)
                TrendArrow(trend: movement.trend)
            }
            if let trend = movement.trend {
                Text(trendText(trend))
                    .font(.peakRow)
                    .foregroundStyle(.peakTextSecondary)
            }
            if let record = movement.record {
                let best = record.bestSet.map { Formatting.set($0, unit: unit) } ?? format(record.value, mainMetric)
                Text("Best: \(best) · \(record.date.formatted(.dateTime.day().month()))")
                    .font(.peakRow)
                    .foregroundStyle(.peakTextSecondary)
            }
        }
    }

    private func trendText(_ trend: TrendChange) -> LocalizedStringKey {
        let change = Formatting.percent(abs(trend.change))
        return switch trend.trend {
        case .rising: "Up \(change) on the sessions before"
        case .steady: "About the same as the sessions before"
        case .falling: "Down \(change) on the sessions before"
        }
    }

    // MARK: Sessions

    private var sessionList: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            SectionHeader("Sessions")
            VStack(spacing: 0) {
                ForEach(movement.points.reversed(), id: \.sessionID) { point in
                    Button {
                        open(point.sessionID)
                    } label: {
                        sessionRow(point)
                    }
                    .buttonStyle(.plain)
                }
            }
            .glassTable()
        }
    }

    private func sessionRow(_ point: MovementPoint) -> some View {
        HStack(spacing: Spacing.xSmall) {
            VStack(alignment: .leading, spacing: 2) {
                Text(point.date, format: .dateTime.weekday(.abbreviated).day().month())
                    .foregroundStyle(.peakTextPrimary)
                if point.isDateEstimated {
                    Text("Date estimated")
                        .font(.peakDetail)
                        .foregroundStyle(.peakTextTertiary)
                }
            }
            if point.isRecord {
                Image(systemName: "star.fill")
                    .font(.peakDetail)
                    .foregroundStyle(.peakTrendRising)
                    .accessibilityLabel(Text("Record"))
            }
            Spacer(minLength: Spacing.xSmall)
            Text(verbatim: summary(of: point))
                .monospacedDigit()
                .foregroundStyle(.peakTextSecondary)
                .multilineTextAlignment(.trailing)
        }
        .font(.peakRow)
        .padding(.horizontal, Spacing.xSmall)
        .frame(minHeight: Metrics.minTouchTarget)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Opens the workout"))
    }

    private func summary(of point: MovementPoint) -> String {
        if movement.isCardio {
            return [
                point.distanceKm.map(Formatting.distance),
                point.durationSec.map { Formatting.duration(TimeInterval($0)) },
            ].compactMap(\.self).joined(separator: " · ")
        }
        let best = point.bestSet.map { Formatting.set($0, unit: unit) } ?? ""
        return movement.isBodyweight
            ? best : "\(best) · \(Formatting.weight(point.volumeKg, unit: unit, fractionLength: 0))"
    }

    // MARK: Metrics

    /// What the chart can show for this kind of movement; the first is what its trend follows.
    private var metrics: [Metric] {
        if movement.isCardio {
            return [
                movement.points.contains { $0.distanceKm != nil } ? Metric.distance : nil,
                movement.points.contains { $0.durationSec != nil } ? Metric.minutes : nil,
            ].compactMap(\.self)
        }
        return movement.isBodyweight ? [.reps, .sets] : [.oneRepMax, .weight, .reps, .volume]
    }

    /// The measure the record and the trend follow (MovementPoint.value).
    private var mainMetric: Metric { metrics.first ?? .reps }

    private func title(of metric: Metric) -> LocalizedStringKey {
        switch metric {
        case .oneRepMax: "Est. 1RM"
        case .weight: "Weight"
        case .reps: "Reps"
        case .volume: "Volume"
        case .sets: "Sets"
        case .distance: "Distance"
        case .minutes: "Duration"
        }
    }

    private func value(of point: MovementPoint, _ metric: Metric) -> Double? {
        switch metric {
        case .oneRepMax: point.bestSet.map(PerformanceAnalysis.estimatedOneRepMax)
        case .weight: point.bestSet?.weightKg
        case .reps: point.bestSet.map { Double($0.reps) }
        case .volume: point.volumeKg
        case .sets: Double(point.doneSets)
        case .distance: point.distanceKm
        case .minutes: point.durationSec.map { Double($0) / 60 }
        }
    }

    /// The value as the chart plots it: weights in the user's unit.
    private func shown(_ value: Double, _ metric: Metric) -> Double {
        switch metric {
        case .oneRepMax, .weight, .volume: WeightUnits.displayValue(kg: value, in: unit)
        default: value
        }
    }

    /// Weights are stored in kg and shown in the user's unit.
    private func format(_ value: Double, _ metric: Metric) -> String {
        switch metric {
        case .oneRepMax, .weight: Formatting.weight(value, unit: unit, fractionLength: 1)
        case .volume: Formatting.weight(value, unit: unit, fractionLength: 0)
        case .reps, .sets: value.formatted(.number.precision(.fractionLength(0)))
        case .distance: Formatting.distance(value)
        case .minutes: Formatting.duration(value * 60)
        }
    }
}
