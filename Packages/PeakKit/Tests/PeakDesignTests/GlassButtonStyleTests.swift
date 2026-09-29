import SwiftUI
import Testing

@testable import PeakDesign

@Suite struct GlassButtonStyleTests {
    @Test func roleChoosesTone() {
        #expect(PeakGlassButtonStyle.tone(for: .confirm) == .positive)
        #expect(PeakGlassButtonStyle.tone(for: .destructive) == .destructive)
        #expect(PeakGlassButtonStyle.tone(for: .cancel) == .destructive)
        #expect(PeakGlassButtonStyle.tone(for: .close) == .neutral)
        #expect(PeakGlassButtonStyle.tone(for: nil) == .neutral)
    }
}
