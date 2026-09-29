import Foundation

/// Weights are stored in kg; imperial users see pounds rounded to 0.5 lb.
public enum WeightUnits {
    public static let poundsPerKilogram = 2.204_622_621_8

    /// The value to show: kg as stored, or lb rounded to the nearest 0.5.
    public static func displayValue(kg: Double, in system: UnitSystem) -> Double {
        switch system {
        case .metric: kg
        case .imperial: (kg * poundsPerKilogram * 2).rounded() / 2
        }
    }

    /// A value the user typed, converted to kg for storage.
    public static func kilograms(fromDisplayValue value: Double, in system: UnitSystem) -> Double {
        switch system {
        case .metric: value
        case .imperial: value / poundsPerKilogram
        }
    }
}
