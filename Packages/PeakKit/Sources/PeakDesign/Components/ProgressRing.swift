import SwiftUI

/// A circular progress ring, like the step ring on the Home screen (80 pt, 8 pt stroke).
///
/// Progress above 1 draws a full ring; show the real percentage next to it. VoiceOver reads it as a percentage.
public struct ProgressRing: View {
    private let progress: Double
    private let tint: Color
    private let lineWidth: CGFloat

    public init(progress: Double, tint: Color, lineWidth: CGFloat = 8) {
        self.progress = progress
        self.tint = tint
        self.lineWidth = lineWidth
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(.peakFillControl, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: Self.clamped(progress))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
        .animation(.smooth, value: progress)
        .accessibilityElement()
        .accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(0))))
    }

    static func clamped(_ progress: Double) -> Double {
        guard progress.isFinite else { return 0 }
        return min(max(progress, 0), 1)
    }
}
