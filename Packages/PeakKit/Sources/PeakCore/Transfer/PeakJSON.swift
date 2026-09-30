import Foundation

/// A calendar day without a time or time zone, written as "yyyy-MM-dd" (a session's `date`).
public struct LocalDate: Codable, Hashable, Comparable, Sendable, CustomStringConvertible {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// The day `date` falls on in `calendar`.
    public init(_ date: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    /// Parses "yyyy-MM-dd"; `nil` for any other shape or a day that does not exist ("2026-02-30").
    public init?(_ text: String) {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
            let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else { return nil }
        let components = DateComponents(year: year, month: month, day: day)
        guard
            Self.gregorian.date(from: components).map({ LocalDate($0, calendar: Self.gregorian) })
                == LocalDate(year: year, month: month, day: day)
        else { return nil }
        self.init(year: year, month: month, day: day)
    }

    /// Midnight of this day in `calendar`.
    public func date(in calendar: Calendar = .current) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public static func < (lhs: LocalDate, rhs: LocalDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let value = LocalDate(text) else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Expected a date as yyyy-MM-dd, found \"\(text)\"")
        }
        self = value
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }

    private static let gregorian: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()
}

/// Coders for Peak JSON. Timestamps are ISO 8601 with milliseconds when written ("2026-09-29T07:00:00.000Z") and
/// accepted with or without fractional seconds and with any offset when read.
public enum PeakJSON {
    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.formatted(withFraction))
        }
        return encoder
    }

    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            if let date = (try? withFraction.parse(text)) ?? (try? withoutFraction.parse(text)) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Expected an ISO 8601 timestamp, found \"\(text)\"")
        }
        return decoder
    }

    public static func encode(_ data: PeakExportV1) throws -> Data {
        try encoder().encode(data)
    }

    public static func decode(_ data: Data) throws -> PeakExportV1 {
        try decoder().decode(PeakExportV1.self, from: data)
    }

    private static let withFraction = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private static let withoutFraction = Date.ISO8601FormatStyle()
}
