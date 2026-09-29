import Foundation
import SwiftData

/// Water intake as a log of changes; the day's total is their sum and never goes below zero.
@MainActor
public final class WaterRepository {
    private let context: ModelContext
    private let calendar: Calendar

    public init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    /// The total for the day containing `date`, in ml.
    public func total(on date: Date = .now) throws -> Int {
        max(0, try logs(on: date).reduce(0) { $0 + $1.amountMl })
    }

    /// Adds water. Non-positive amounts are ignored.
    @discardableResult
    public func add(_ amountMl: Int, at date: Date = .now, source: WaterSource = .app) throws -> Int {
        guard amountMl > 0 else { return try total(on: date) }
        context.insert(WaterLog(amountMl: amountMl, date: date, source: source))
        return try total(on: date)
    }

    /// Removes water, but never more than the day's total. Returns the new total.
    @discardableResult
    public func remove(_ amountMl: Int, at date: Date = .now, source: WaterSource = .app) throws -> Int {
        let current = try total(on: date)
        let removal = min(max(0, amountMl), current)
        guard removal > 0 else { return current }
        context.insert(WaterLog(amountMl: -removal, date: date, source: source))
        return current - removal
    }

    private func logs(on date: Date) throws -> [WaterLog] {
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        return try context.fetch(
            FetchDescriptor<WaterLog>(predicate: #Predicate { $0.date >= start && $0.date < end })
        )
    }
}
