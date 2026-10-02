import Accessibility
import Charts
import PeakDesign
import SwiftUI

/// One value per session over time: a line with a point per session, records in green. Used by the movement and
/// workout details.
struct ProgressChart: View {
    struct Point: Identifiable {
        let id: UUID
        let date: Date
        /// In the unit shown (lb for imperial users).
        let value: Double
        /// The value as text, for VoiceOver.
        let text: String
        var isRecord = false
    }

    let points: [Point]
    /// The measure's name, read by VoiceOver for the chart.
    let label: Text

    var body: some View {
        Chart(points) { point in
            LineMark(x: .value("Date", point.date), y: .value("Value", point.value))
                .foregroundStyle(.peakTextSecondary)
                .interpolationMethod(.monotone)
            PointMark(x: .value("Date", point.date), y: .value("Value", point.value))
                .foregroundStyle(point.isRecord ? .peakTrendRising : .peakTextPrimary)
                .symbolSize(point.isRecord ? 80 : 40)
        }
        .chartYScale(domain: .automatic(includesZero: false))
        // Room on both sides: date labels are centred on their tick, so one at an edge would be cut off.
        .chartXScale(range: .plotDimension(startPadding: 24, endPadding: 24))
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: .dateTime.day().month(.abbreviated), anchor: .top)
            }
        }
        .frame(height: 220)
        .chartAccessibility(
            label: label,
            summary: summary,
            descriptor: SeriesChartDescriptor(
                points: points.map { .init(date: $0.date, value: $0.value, text: $0.text) }))
    }

    /// "6 sessions, from 29.3 kg to 35.8 kg".
    private var summary: String {
        guard let first = points.first, let last = points.last else { return "" }
        return String(localized: "\(points.count) Sessions, from \(first.text) to \(last.text)")
    }
}

extension View {
    /// A chart as one VoiceOver element: its name, a summary, and the audio graph for the values. Its axis labels
    /// are drawn, not views, so the chart has to speak for them.
    func chartAccessibility(label: Text, summary: String, descriptor: SeriesChartDescriptor) -> some View {
        accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityValue(Text(verbatim: summary))
            .accessibilityChartDescriptor(descriptor)
    }
}

/// The audio graph of a chart with one value per date.
struct SeriesChartDescriptor: AXChartDescriptorRepresentable {
    struct Point {
        let date: Date
        let value: Double
        let text: String
    }

    let points: [Point]

    func makeChartDescriptor() -> AXChartDescriptor {
        let dates = points.map(\.date.timeIntervalSince1970)
        let values = points.map(\.value)
        let xAxis = AXNumericDataAxisDescriptor(
            title: String(localized: "Date"),
            range: (dates.min() ?? 0)...(dates.max() ?? 1),
            gridlinePositions: []
        ) { Date(timeIntervalSince1970: $0).formatted(.dateTime.day().month().year()) }
        let yAxis = AXNumericDataAxisDescriptor(
            title: String(localized: "Value"),
            range: (values.min() ?? 0)...(values.max() ?? 1),
            gridlinePositions: []
        ) { $0.formatted() }
        let series = AXDataSeriesDescriptor(
            name: "", isContinuous: true,
            dataPoints: points.map {
                AXDataPoint(x: $0.date.timeIntervalSince1970, y: $0.value, label: $0.text)
            })
        return AXChartDescriptor(title: nil, summary: nil, xAxis: xAxis, yAxis: yAxis, series: [series])
    }
}
