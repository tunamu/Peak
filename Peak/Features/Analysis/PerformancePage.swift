import Charts
import PeakCore
import PeakDesign
import SwiftUI

/// F11-04: the period's totals against the period before, weekly volume and sessions, muscle balance, and every
/// movement and workout with its trend, each opening its chart (ADR 0020).
struct PerformancePage: View {
    let sessions: [AnalysisSession]
    @Binding var period: AnalysisPeriod

    @Environment(SettingsStore.self) private var settings
    @Environment(\.calendar) private var calendar
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let now = Date.now
        let range = period.range(now: now, calendar: calendar)
        let inPeriod = sessions.filter { range?.contains($0.date) ?? true }
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.section) {
                    summary(range: range, now: now)
                    weeklyVolume(range: range, now: now)
                    muscleBalance(inPeriod).id("muscles")
                    movements(in: range).id("movements")
                    workouts(in: range).id("workouts")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.bottom, Spacing.medium)
            }
            #if DEBUG
                // Screenshot helper: `-PeakAnalysisScroll muscles|movements|workouts`.
                .task {
                    guard let section = UserDefaults.standard.string(forKey: "PeakAnalysisScroll") else { return }
                    try? await Task.sleep(for: .milliseconds(500))
                    proxy.scrollTo(section, anchor: .top)
                }
            #endif
        }
        .peakHaptic(.selection, trigger: period)
    }

    private var unit: UnitSystem { settings.unitSystem }

    // MARK: Summary

    private func summary(range: Range<Date>?, now: Date) -> some View {
        let current = PerformanceAnalysis.totals(of: sessions, in: range)
        let previousRange = period.previousRange(now: now, calendar: calendar)
        let previous = previousRange.map { PerformanceAnalysis.totals(of: sessions, in: $0) }
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: Spacing.medium, alignment: .top),
            count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)

        return VStack(alignment: .leading, spacing: Spacing.small) {
            // Side by side; one above the other at accessibility text sizes (F10-02).
            let layout =
                dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
            layout {
                Text("Summary")
                    .font(.peakSectionTitle)
                    .foregroundStyle(.peakTextPrimary)
                    .accessibilityAddTraits(.isHeader)
                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer(minLength: Spacing.xSmall)
                }
                periodMenu
            }
            GlassEffectContainer(spacing: Spacing.medium) {
                LazyVGrid(columns: columns, spacing: Spacing.medium) {
                    StatTile(
                        title: "Workouts", value: current.sessions.formatted(),
                        change: previous.flatMap {
                            PerformanceAnalysis.change(from: Double($0.sessions), to: Double(current.sessions))
                        })
                    StatTile(
                        title: "Volume", value: Formatting.weight(current.volumeKg, unit: unit, fractionLength: 0),
                        change: previous.flatMap {
                            PerformanceAnalysis.change(from: $0.volumeKg, to: current.volumeKg)
                        })
                    StatTile(
                        title: "Sets", value: current.doneSets.formatted(),
                        change: previous.flatMap {
                            PerformanceAnalysis.change(from: Double($0.doneSets), to: Double(current.doneSets))
                        })
                    StatTile(
                        title: "Targets Hit", value: current.successRate.map(Formatting.percent) ?? "–",
                        change: previous.flatMap { before in
                            guard let was = before.successRate, let now = current.successRate else { return nil }
                            return PerformanceAnalysis.change(from: was, to: now)
                        })
                }
            }
        }
    }

    private var periodMenu: some View {
        Menu {
            Picker("Period", selection: $period) {
                ForEach(AnalysisPeriod.allCases, id: \.self) { period in
                    Text(period.title).tag(period)
                }
            }
        } label: {
            HStack(spacing: Spacing.xxSmall) {
                Text(period.title)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.peakDetail)
                    .accessibilityHidden(true)
            }
            .font(.peakRow)
            .foregroundStyle(.peakTextSecondary)
            .frame(minHeight: Metrics.minTouchTarget)
            .contentShape(.rect)
        }
        .accessibilityLabel(Text("Period"))
        .accessibilityValue(Text(period.title))
    }

    // MARK: Weeks

    private func weeklyVolume(range: Range<Date>?, now: Date) -> some View {
        let weeks = PerformanceAnalysis.weeks(of: sessions, in: range, now: now, calendar: calendar)
        let streak = PerformanceAnalysis.streakWeeks(of: sessions, now: now, calendar: calendar)
        return VStack(alignment: .leading, spacing: Spacing.small) {
            SectionHeader("Weekly Volume")
            VStack(alignment: .leading, spacing: Spacing.small) {
                Text("\(streak) weeks in a row")
                    .font(.peakDetail)
                    .foregroundStyle(.peakTextSecondary)
                Chart(weeks) { week in
                    BarMark(
                        x: .value("Week", week.start, unit: .weekOfYear),
                        y: .value("Volume", WeightUnits.displayValue(kg: week.volumeKg, in: unit))
                    )
                    .foregroundStyle(.peakWater)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }
                .frame(height: 180)
                .chartAccessibility(
                    label: Text("Weekly Volume"),
                    summary: weeklySummary(weeks),
                    descriptor: SeriesChartDescriptor(
                        points: weeks.map { week in
                            .init(
                                date: week.start, value: WeightUnits.displayValue(kg: week.volumeKg, in: unit),
                                text: "\(Formatting.weight(week.volumeKg, unit: unit, fractionLength: 0)), "
                                    + String(localized: "\(week.sessions) Workouts"))
                        }))
            }
            .glassCard()
        }
    }

    /// "13 weeks, most 12,630 kg".
    private func weeklySummary(_ weeks: [WeekTotals]) -> String {
        let most = weeks.map(\.volumeKg).max() ?? 0
        return String(localized: "\(weeks.count) weeks, most \(Formatting.weight(most, unit: unit, fractionLength: 0))")
    }

    // MARK: Muscle groups

    @ViewBuilder
    private func muscleBalance(_ inPeriod: [AnalysisSession]) -> some View {
        let shares = PerformanceAnalysis.muscleShares(of: inPeriod)
        if !shares.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.small) {
                SectionHeader("Muscle Balance")
                VStack(alignment: .leading, spacing: Spacing.small) {
                    Text("Sets done per muscle group")
                        .font(.peakDetail)
                        .foregroundStyle(.peakTextSecondary)
                    ForEach(shares) { share in
                        muscleRow(share, widest: shares.first?.sets ?? 1)
                    }
                }
                .glassCard()
            }
        }
    }

    private func muscleRow(_ share: MuscleShare, widest: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            HStack {
                Text(share.group.title)
                    .foregroundStyle(.peakTextPrimary)
                Spacer(minLength: Spacing.xSmall)
                Text(verbatim: "\(share.sets.formatted()) · \(Formatting.percent(share.share))")
                    .monospacedDigit()
                    .foregroundStyle(.peakTextSecondary)
            }
            .font(.peakRow)
            Capsule()
                .fill(.peakFillControl)
                .frame(height: 6)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(.peakTextPrimary)
                            .frame(width: proxy.size.width * CGFloat(share.sets) / CGFloat(max(widest, 1)))
                    }
                }
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Lists

    @ViewBuilder
    private func movements(in range: Range<Date>?) -> some View {
        let movements = PerformanceAnalysis.movements(in: sessions).filter { movement in
            movement.points.contains { range?.contains($0.date) ?? true }
        }
        if !movements.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.small) {
                SectionHeader("Movements")
                VStack(spacing: 0) {
                    ForEach(movements) { movement in
                        NavigationLink(value: AnalysisView.Route.movement(key: movement.key)) {
                            AnalysisRow(title: movement.name, detail: detail(of: movement), trend: movement.trend)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .glassTable()
            }
        }
    }

    @ViewBuilder
    private func workouts(in range: Range<Date>?) -> some View {
        let workouts = PerformanceAnalysis.workouts(in: sessions).filter { workout in
            workout.points.contains { range?.contains($0.date) ?? true }
        }
        if !workouts.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.small) {
                SectionHeader("Workouts")
                VStack(spacing: 0) {
                    ForEach(workouts) { workout in
                        NavigationLink(value: AnalysisView.Route.workout(id: workout.id)) {
                            AnalysisRow(
                                title: workout.title,
                                detail: String(localized: "\(workout.points.count) Workouts"),
                                trend: workout.trend)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .glassTable()
            }
        }
    }

    /// The latest best set, or a walk's distance or minutes.
    private func detail(of movement: MovementSummary) -> String {
        guard let latest = movement.latest else { return "" }
        if movement.isCardio {
            return latest.distanceKm.map(Formatting.distance)
                ?? latest.durationSec.map { Formatting.duration(TimeInterval($0)) } ?? ""
        }
        return latest.bestSet.map { Formatting.set($0, unit: unit) } ?? ""
    }
}
