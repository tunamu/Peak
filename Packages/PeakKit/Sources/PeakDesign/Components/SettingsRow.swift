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

    private let title: LocalizedStringKey
    private let accessory: Accessory
    private let perform: () -> Void

    public init(_ title: LocalizedStringKey, accessory: Accessory = .none, perform: @escaping () -> Void) {
        self.title = title
        self.accessory = accessory
        self.perform = perform
    }

    public var body: some View {
        Button(action: perform) {
            HStack(spacing: Spacing.small) {
                Text(title)
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

/// Highlights the row while it is pressed, like a list cell.
private struct RowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                .peakFillControl.opacity(configuration.isPressed ? 1 : 0),
                in: .rect(cornerRadius: Radius.control)
            )
    }
}
