import PeakCore
import PeakDesign
import SwiftData
import SwiftUI

/// C-06: the day's water against the goal. Tap to add or remove (S-01). Days after today cannot change.
struct WaterTile: View {
    let day: Date
    let isFuture: Bool

    @Environment(SettingsStore.self) private var settings
    @Query private var logs: [WaterLog]
    @State private var isSheetShown = false

    init(day: Date, isFuture: Bool, calendar: Calendar) {
        self.day = day
        self.isFuture = isFuture
        _logs = Query(filter: WaterTile.predicate(for: day, calendar: calendar))
    }

    /// The logs of the day containing `day`.
    static func predicate(for day: Date, calendar: Calendar) -> Predicate<WaterLog> {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return #Predicate { $0.date >= start && $0.date < end }
    }

    var body: some View {
        Button {
            isSheetShown = true
        } label: {
            VStack(spacing: Spacing.xSmall) {
                Image(systemName: "drop.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.peakWater)
                    .accessibilityHidden(true)
                VStack(spacing: 2) {
                    Text("Water Intake")
                        .font(.peakCardLabel)
                        .foregroundStyle(.peakTextSecondary)
                    Text(verbatim: Formatting.liters(WaterSheet.total(of: logs), of: settings.waterGoalMl))
                        .font(.peakCardValue)
                        .monospacedDigit()
                        .foregroundStyle(.peakTextPrimary)
                }
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .glassCard()
            .contentShape(.rect(cornerRadius: Radius.card))
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Adds or removes water"))
        .sheet(isPresented: $isSheetShown) {
            WaterSheet(day: day, logs: logs)
        }
    }
}

/// S-01: pick an amount on the four-stop slider, then Add or Remove. The day's total goes to Apple Health as one
/// sample.
struct WaterSheet: View {
    let day: Date
    let logs: [WaterLog]

    @Environment(SettingsStore.self) private var settings
    @Environment(HealthConnection.self) private var health
    @Environment(\.modelContext) private var modelContext
    @Environment(\.calendar) private var calendar
    @State private var stop = 0.0
    @State private var changes = 0

    static func total(of logs: [WaterLog]) -> Int {
        max(0, logs.reduce(0) { $0 + $1.amountMl })
    }

    private var total: Int { Self.total(of: logs) }
    private var amounts: [Int] { settings.quickWaterAmounts }
    private var amount: Int { amounts[min(Int(stop.rounded()), amounts.count - 1)] }

    var body: some View {
        VStack(spacing: Spacing.medium) {
            VStack(spacing: Spacing.xxSmall) {
                Image(systemName: "drop.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.peakWater)
                    .accessibilityHidden(true)
                Text("Water Intake")
                    .font(.peakCardLabel)
                    .foregroundStyle(.peakTextSecondary)
                Text(verbatim: Formatting.liters(total, of: settings.waterGoalMl))
                    .font(.peakCardValue)
                    .monospacedDigit()
                    .foregroundStyle(.peakTextPrimary)
                    .contentTransition(.numericText(value: Double(total)))
            }
            .accessibilityElement(children: .combine)

            VStack(spacing: Spacing.xSmall) {
                Text("Add Amount")
                    .font(.peakCardLabel)
                    .foregroundStyle(.peakTextSecondary)
                Slider(value: $stop, in: 0...Double(max(amounts.count - 1, 1)), step: 1) {
                    Text("Add Amount")
                }
                .tint(.peakWater)
                .accessibilityValue(Text(verbatim: Formatting.waterAmount(amount)))
                stopLabels
            }

            GlassEffectContainer(spacing: Spacing.medium) {
                HStack(spacing: Spacing.medium) {
                    Button(role: .destructive) {
                        change(by: -amount)
                    } label: {
                        Text("Remove").frame(maxWidth: .infinity)
                    }
                    .disabled(total == 0)

                    Button {
                        change(by: amount)
                    } label: {
                        Label("Add", systemImage: "plus")
                            .labelStyle(.titleAndTrailingIcon)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.peakGlass(.positive))
                }
                .buttonStyle(.peakGlass)
            }
        }
        .multilineTextAlignment(.center)
        .padding(Spacing.large)
        .sensoryFeedback(.increase, trigger: changes)
        .fittedSheet()
    }

    /// The amounts under the slider, each centered on its stop.
    private var stopLabels: some View {
        GeometryReader { proxy in
            ForEach(Array(amounts.enumerated()), id: \.offset) { index, value in
                Text(verbatim: Formatting.waterAmount(value))
                    .font(.peakDetail)
                    .monospacedDigit()
                    .foregroundStyle(index == Int(stop.rounded()) ? .peakTextPrimary : .peakTextTertiary)
                    .fixedSize()
                    .position(
                        x: stopPosition(index, width: proxy.size.width),
                        y: proxy.size.height / 2
                    )
            }
        }
        .frame(height: 18)
        .accessibilityHidden(true)
    }

    private func stopPosition(_ index: Int, width: CGFloat) -> CGFloat {
        // The slider's knob travels between half a knob width from each edge.
        let inset: CGFloat = 14
        let fraction = amounts.count > 1 ? CGFloat(index) / CGFloat(amounts.count - 1) : 0
        return inset + (width - 2 * inset) * fraction
    }

    private func change(by milliliters: Int) {
        let repository = WaterRepository(context: modelContext, calendar: calendar)
        let date = calendar.isDateInToday(day) ? Date.now : calendar.startOfDay(for: day).addingTimeInterval(12 * 3_600)
        let newTotal =
            try?
            (milliliters > 0
            ? repository.add(milliliters, at: date) : repository.remove(-milliliters, at: date))
        try? modelContext.save()
        changes += 1
        guard let newTotal, health.status == .connected else { return }
        Task {
            try? await health.service.setWaterTotal(newTotal, on: day)
        }
    }
}

extension LabelStyle where Self == TitleAndTrailingIconLabelStyle {
    /// "Add +": the title first, then the symbol.
    static var titleAndTrailingIcon: TitleAndTrailingIconLabelStyle { .init() }
}

struct TitleAndTrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Spacing.xSmall) {
            configuration.title
            configuration.icon
        }
    }
}

#if DEBUG
    #Preview("Tile") {
        WaterTile(day: .now, isFuture: false, calendar: .current)
            .frame(width: 172, height: 146)
            .padding()
            .background(.peakCanvas)
            .previewEnvironment()
    }
#endif
