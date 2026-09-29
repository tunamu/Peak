import Foundation

/// Number formats shared by several screens, always in the user's locale.
enum Formatting {
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
}
