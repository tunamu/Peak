import Testing

@testable import PeakDesign

@Suite struct ProgressRingTests {
    @Test(arguments: [(-0.5, 0.0), (0.0, 0.0), (0.75, 0.75), (1.0, 1.0), (1.4, 1.0), (Double.nan, 0.0)])
    func clampsProgress(_ input: Double, _ expected: Double) {
        #expect(ProgressRing.clamped(input) == expected)
    }
}
