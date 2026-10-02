import Foundation
import PeakCore

/// Number formats shared by several screens, always in the user's locale.
nonisolated enum Formatting {
    /// "4.0 L", "3.25 L" ("4,0 L" in Turkish).
    static func liters(_ milliliters: Int) -> String {
        "\(litersNumber(milliliters)) L"
    }

    /// "1.8 / 4.0 L": the water tile's total and goal.
    static func liters(_ milliliters: Int, of goal: Int) -> String {
        "\(litersNumber(milliliters)) / \(liters(goal))"
    }

    /// "200 ml", "1 L": the water sheet's amounts.
    static func waterAmount(_ milliliters: Int) -> String {
        if milliliters >= 1_000 && milliliters % 1_000 == 0 {
            return "\((milliliters / 1_000).formatted()) L"
        }
        return milliliters >= 1_000 ? liters(milliliters) : "\(milliliters.formatted()) ml"
    }

    private static func litersNumber(_ milliliters: Int) -> String {
        (Double(milliliters) / 1_000).formatted(.number.precision(.fractionLength(1...2)))
    }

    /// "27.5 kg", "60.5 lb": a stored kg weight in the user's unit.
    static func weight(_ kg: Double, unit: UnitSystem, fractionLength: Int = 2) -> String {
        let value = WeightUnits.displayValue(kg: kg, in: unit).formatted(
            .number.precision(.fractionLength(0...fractionLength)))
        return "\(value) \(unit == .metric ? "kg" : "lb")"
    }

    /// "27.5 kg × 9"; a bodyweight set is just "× 12".
    static func set(_ set: SetPerformance, unit: UnitSystem) -> String {
        set.weightKg > 0 ? "\(weight(set.weightKg, unit: unit)) × \(set.reps)" : "× \(set.reps)"
    }

    /// "42 min", or "1 hr 5 min".
    static func duration(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    /// "92%".
    static func percent(_ fraction: Double) -> String {
        fraction.formatted(.percent.precision(.fractionLength(0)))
    }

    /// "2.4 km".
    static func distance(_ kilometers: Double) -> String {
        "\(kilometers.formatted(.number.precision(.fractionLength(0...2)))) km"
    }
}
