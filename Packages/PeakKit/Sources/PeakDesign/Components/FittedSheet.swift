import SwiftUI

extension View {
    /// Sizes a sheet to its content instead of a fixed detent, so it grows with Dynamic Type.
    ///
    /// Apply it to the sheet's root view. Content taller than the screen scrolls.
    public func fittedSheet() -> some View {
        modifier(FittedSheet())
    }
}

private struct FittedSheet: ViewModifier {
    @State private var height: CGFloat = 300

    func body(content: Content) -> some View {
        ScrollView {
            content
                .onGeometryChange(for: CGFloat.self) {
                    $0.size.height
                } action: {
                    height = $0
                }
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.height(height)])
        .presentationDragIndicator(.visible)
    }
}
