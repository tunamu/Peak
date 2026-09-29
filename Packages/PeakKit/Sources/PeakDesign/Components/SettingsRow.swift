import SwiftUI

/// A tappable settings row: a label on the left and an accessory on the right. Design: C-08.
///
/// The whole row is the tap target and at least 44 pt tall, although the design draws it 20 pt tall.
public struct SettingsRow: View {
    public enum Accessory {
        /// A current value, such as "10.000" or ">12".
        case value(String)
        /// An action word, such as "Edit" or "Set".
        case action(LocalizedStringKey)
        /// An SF Symbol, such as `square.and.arrow.up`.
        case icon(String)
        case none
    }

    private let title: Text
    private let accessory: Accessory
    private let perform: () -> Void

    /// A row with a fixed, localized title such as "Daily Step Goal".
    public init(_ title: LocalizedStringKey, accessory: Accessory = .none, perform: @escaping () -> Void) {
        self.title = Text(title)
        self.accessory = accessory
        self.perform = perform
    }

    /// A row titled with text the user wrote, such as a workout name. It is never looked up as a translation key.
    public init(verbatim title: String, accessory: Accessory = .none, perform: @escaping () -> Void) {
        self.title = Text(verbatim: title)
        self.accessory = accessory
        self.perform = perform
    }

    public var body: some View {
        Button(action: perform) {
            HStack(spacing: Spacing.small) {
                title
                    .foregroundStyle(.peakTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                accessoryView
            }
            .font(.peakRow)
            .padding(.horizontal, Spacing.xSmall)
            .frame(minHeight: Metrics.minTouchTarget)
            .contentShape(.rect)
        }
        .buttonStyle(RowButtonStyle())
    }

    @ViewBuilder private var accessoryView: some View {
        switch accessory {
        case .value(let value):
            Text(verbatim: value)
                .monospacedDigit()
                .foregroundStyle(.peakTextTertiary)
        case .action(let title):
            Text(title)
                .foregroundStyle(.peakTextSecondary)
        case .icon(let systemImage):
            Image(systemName: systemImage)
                .foregroundStyle(.peakTextSecondary)
                .accessibilityHidden(true)
        case .none:
            EmptyView()
        }
    }
}

/// Highlights the row while it is pressed, like a list cell, and dims it when disabled.
private struct RowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Row(configuration: configuration)
    }

    // A view, so it can read `isEnabled` from the environment.
    private struct Row: View {
        let configuration: Configuration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .opacity(isEnabled ? 1 : 0.4)
                .background(
                    .peakFillControl.opacity(configuration.isPressed ? 1 : 0),
                    in: .rect(cornerRadius: Radius.control)
                )
        }
    }
}
