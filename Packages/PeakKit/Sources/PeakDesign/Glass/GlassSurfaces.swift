import SwiftUI

// Non-interactive glass containers. For tappable glass use `PeakGlassButtonStyle`.
extension View {
    /// A glass card: design padding (24 horizontal, 16 vertical) and a 20 pt corner radius.
    ///
    /// Also sets the container shape, so a `ConcentricRectangle` inside the card lines up with its corners.
    /// Neighbouring cards should sit in one `GlassEffectContainer`.
    public func glassCard() -> some View {
        padding(.horizontal, Spacing.cardHorizontal)
            .padding(.vertical, Spacing.cardVertical)
            .containerShape(.rect(cornerRadius: Radius.card))
            .glassEffect(.regular, in: .rect(cornerRadius: Radius.card))
    }

    /// A glass table container (16 pt radius, 8 pt padding). Rows inside it are never glass themselves.
    public func glassTable() -> some View {
        padding(Spacing.xSmall)
            .containerShape(.rect(cornerRadius: Radius.control))
            .glassEffect(.regular, in: .rect(cornerRadius: Radius.control))
    }

    /// A glass capsule for a short value, such as "200ml" in a picker sheet.
    public func glassPill() -> some View {
        padding(.horizontal, Spacing.large)
            .frame(minHeight: Metrics.minTouchTarget)
            .glassEffect(.regular, in: .capsule)
    }
}
