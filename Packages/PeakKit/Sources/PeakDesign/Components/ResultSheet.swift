import SwiftUI

/// Whether a `ResultSheet` reports a success or a failure.
public enum ResultKind: Sendable {
    case success
    case failure
}

/// A short result: a large checkmark or cross, a title, a message and the actions that fit the context
/// (Done, Retry). Design: S-09 "Success / Large" and "Error / Large". Plays a success or error haptic when shown.
///
/// ```swift
/// ResultSheet(.success, title: "Import complete", message: Text("42 workouts")) {
///     Button { dismiss() } label: { Text("Done").frame(maxWidth: .infinity) }
/// }
/// ```
public struct ResultSheet<Actions: View>: View {
    private let kind: ResultKind
    private let title: LocalizedStringKey
    private let message: Text?
    private let actions: Actions

    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 52
    @State private var isShown = false

    public init(
        _ kind: ResultKind,
        title: LocalizedStringKey,
        message: Text? = nil,
        @ViewBuilder actions: () -> Actions
    ) {
        self.kind = kind
        self.title = title
        self.message = message
        self.actions = actions()
    }

    public var body: some View {
        VStack(spacing: Spacing.large) {
            Image(systemName: kind == .success ? "checkmark" : "xmark")
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(kind == .success ? .peakEnergyReady : .peakEnergyNotReady)
                .accessibilityHidden(true)

            VStack(spacing: Spacing.xxSmall) {
                Text(title)
                    .font(.peakCardLabel)
                    .foregroundStyle(.peakTextSecondary)
                message?
                    .font(.peakCardValue)
                    .foregroundStyle(.peakTextPrimary)
            }
            .accessibilityElement(children: .combine)

            GlassEffectContainer(spacing: Spacing.medium) {
                HStack(spacing: Spacing.medium) {
                    actions
                }
                .buttonStyle(.peakGlass)
            }
        }
        .multilineTextAlignment(.center)
        .padding(Spacing.large)
        .onAppear { isShown = true }
        .peakHaptic(kind == .success ? .success : .error, trigger: isShown)
        .fittedSheet()
    }
}
