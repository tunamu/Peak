import SwiftUI

/// The design's glass button: a 16 pt rounded rectangle (or a capsule) with an optional green or red tint.
///
/// The tint follows the button's role unless a tone is given:
/// `.confirm` → positive (Add, Update, Finish), `.destructive` and `.cancel` → destructive (Remove, Reset, Cancel),
/// anything else → neutral (Start, Complete Movement).
///
/// ```swift
/// Button("Update", role: .confirm) { … }
///     .buttonStyle(.peakGlass)
/// ```
public struct PeakGlassButtonStyle: ButtonStyle {
    public enum Tone: Sendable {
        case neutral
        case positive
        case destructive
    }

    public enum Shape: Sendable {
        /// 16 pt corners, like Start and Finish Workout.
        case roundedRectangle
        /// A pill, like "Start Today's Workout".
        case capsule
    }

    private let tone: Tone?
    private let shape: Shape

    public init(tone: Tone? = nil, shape: Shape = .roundedRectangle) {
        self.tone = tone
        self.shape = shape
    }

    public func makeBody(configuration: Configuration) -> some View {
        StyledLabel(
            label: configuration.label,
            glass: glass(for: tone ?? Self.tone(for: configuration.role)),
            shape: shape == .capsule ? AnyShape(.capsule) : AnyShape(.rect(cornerRadius: Radius.control))
        )
    }

    static func tone(for role: ButtonRole?) -> Tone {
        switch role {
        case .confirm?: .positive
        case .destructive?, .cancel?: .destructive
        default: .neutral
        }
    }

    private func glass(for tone: Tone) -> Glass {
        switch tone {
        case .neutral: .regular.interactive()
        case .positive: .regular.tint(.peakTintPositive).interactive()
        case .destructive: .regular.tint(.peakTintDestructive).interactive()
        }
    }

    // A view, not inline in makeBody, so it can read `isEnabled` from the environment.
    private struct StyledLabel: View {
        let label: Configuration.Label
        let glass: Glass
        let shape: AnyShape

        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            label
                .font(.peakCardLabel)
                .foregroundStyle(.peakTextPrimary)
                .opacity(isEnabled ? 1 : 0.4)
                .padding(.horizontal, Spacing.large)
                .frame(minHeight: Metrics.minTouchTarget)
                .contentShape(shape)
                .glassEffect(glass, in: shape)
        }
    }
}

extension ButtonStyle where Self == PeakGlassButtonStyle {
    /// Glass button tinted by its role.
    public static var peakGlass: PeakGlassButtonStyle { PeakGlassButtonStyle() }

    /// Glass button with an explicit tone, for actions whose role does not describe the color (such as Add).
    public static func peakGlass(_ tone: PeakGlassButtonStyle.Tone) -> PeakGlassButtonStyle {
        PeakGlassButtonStyle(tone: tone)
    }

    /// Glass pill tinted by its role.
    public static var peakGlassPill: PeakGlassButtonStyle { PeakGlassButtonStyle(shape: .capsule) }
}
