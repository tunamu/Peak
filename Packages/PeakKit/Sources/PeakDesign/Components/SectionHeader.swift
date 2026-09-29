import SwiftUI

/// A section title ("Dashboard", "Goal Settings") with an optional trailing action ("+ New"). Design: C-07.
public struct SectionHeader: View {
    private let title: LocalizedStringKey
    private let action: Action?

    public struct Action {
        let title: LocalizedStringKey
        let systemImage: String
        let perform: () -> Void

        public init(_ title: LocalizedStringKey, systemImage: String = "plus.circle", perform: @escaping () -> Void) {
            self.title = title
            self.systemImage = systemImage
            self.perform = perform
        }
    }

    public init(_ title: LocalizedStringKey, action: Action? = nil) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xSmall) {
            Text(title)
                .font(.peakSectionTitle)
                .foregroundStyle(.peakTextPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            if let action {
                Button(action: action.perform) {
                    Label(action.title, systemImage: action.systemImage)
                        .font(.peakRow)
                        // Tappable, so secondary rather than the design's tertiary (ADR 0017).
                        .foregroundStyle(.peakTextSecondary)
                        .frame(minHeight: Metrics.minTouchTarget)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
