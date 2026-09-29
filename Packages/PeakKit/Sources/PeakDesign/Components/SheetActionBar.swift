import SwiftUI

/// The pair of glass buttons at the bottom of an editing sheet: Cancel (red tint) and Update or Create (green tint).
///
/// ```swift
/// .safeAreaInset(edge: .bottom) {
///     SheetActionBar(cancel: "Cancel", confirm: "Update", isConfirmEnabled: !name.isEmpty) {
///         dismiss()
///     } onConfirm: {
///         save()
///     }
/// }
/// ```
public struct SheetActionBar: View {
    private let cancel: LocalizedStringKey
    private let confirm: LocalizedStringKey
    private let isConfirmEnabled: Bool
    private let onCancel: () -> Void
    private let onConfirm: () -> Void

    public init(
        cancel: LocalizedStringKey,
        confirm: LocalizedStringKey,
        isConfirmEnabled: Bool = true,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping () -> Void
    ) {
        self.cancel = cancel
        self.confirm = confirm
        self.isConfirmEnabled = isConfirmEnabled
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }

    public var body: some View {
        GlassEffectContainer(spacing: Spacing.medium) {
            HStack(spacing: Spacing.medium) {
                Button(role: .cancel, action: onCancel) {
                    Text(cancel).frame(maxWidth: .infinity)
                }
                Button(role: .confirm, action: onConfirm) {
                    Text(confirm).frame(maxWidth: .infinity)
                }
                .disabled(!isConfirmEnabled)
            }
            .buttonStyle(.peakGlass)
        }
        .padding(.horizontal, Spacing.large)
        .padding(.vertical, Spacing.small)
    }
}
