import Foundation
import PeakCore
import Testing

/// Peak JSON v1: the example files validate against the JSON Schema, and the schema and the DTOs describe the same
/// fields (F7-01).
@Suite struct PeakJSONSchemaTests {
    static let schemaFolder = URL(filePath: #filePath)
        .deletingLastPathComponent()  // PeakCoreTests
        .deletingLastPathComponent()  // Tests
        .deletingLastPathComponent()  // PeakKit
        .deletingLastPathComponent()  // Packages
        .deletingLastPathComponent()  // repo root
        .appending(path: "docs/schema")

    static let examples = ["full.json", "minimal.json"]

    let validator: JSONSchemaValidator

    init() throws {
        validator = try JSONSchemaValidator(
            schema: Data(contentsOf: Self.schemaFolder.appending(path: "peak-workout-data.v1.schema.json")))
    }

    static func example(_ name: String) throws -> Data {
        try Data(contentsOf: schemaFolder.appending(path: "examples/\(name)"))
    }

    @Test(arguments: examples)
    func examplesMatchTheSchema(_ name: String) throws {
        #expect(try validator.errors(in: Self.example(name)) == [])
    }

    @Test(arguments: examples)
    func examplesDecode(_ name: String) throws {
        let data = try PeakJSON.decode(Self.example(name))
        #expect(!data.sessions.isEmpty)
    }

    /// The DTOs keep every field of the full example, and what they write is valid again.
    @Test func decodingAndEncodingKeepsEveryField() throws {
        let original = try Self.example("full.json")
        let encoded = try PeakJSON.encode(PeakJSON.decode(original))

        #expect(try validator.errors(in: encoded) == [])
        #expect(try Self.keyPaths(original).subtracting(Self.keyPaths(encoded)) == [])
        #expect(try PeakJSON.decode(encoded) == PeakJSON.decode(original))
    }

    /// Every property the schema declares appears in the full example, so the test above covers the whole schema.
    @Test func fullExampleUsesEverySchemaProperty() throws {
        let schema = try Data(contentsOf: Self.schemaFolder.appending(path: "peak-workout-data.v1.schema.json"))
        let declared = try Self.propertyNames(in: JSONSerialization.jsonObject(with: schema))
        let used = try Set(Self.keyPaths(Self.example("full.json")).compactMap { $0.split(separator: ".").last })
        #expect(declared.subtracting(used.map(String.init)) == [])
    }

    /// A file with one session holding one exercise.
    static func exercise(_ json: String) -> String {
        #"{ "sessions": [ { "exercises": [ \#(json) ] } ] }"#
    }

    /// A file with one set of "Row".
    static func set(_ json: String) -> String {
        exercise(#"{ "exerciseName": "Row", "sets": [ \#(json) ] }"#)
    }

    /// A file with one session and no exercises.
    static func session(_ fields: String) -> String {
        #"{ "sessions": [ { \#(fields), "exercises": [] } ] }"#
    }

    /// A file with one routine using `schedule`.
    static func schedule(_ json: String) -> String {
        #"{ "routines": [ { "name": "A", "schedule": \#(json) } ], "sessions": [] }"#
    }

    @Test(arguments: [
        ("no sessions", #"{ "exercises": [] }"#),
        ("unknown property", #"{ "sessions": [], "session": [] }"#),
        ("wrong version", #"{ "schemaVersion": 2, "sessions": [] }"#),
        ("set without reps", set(#"{ "weight": 60 }"#)),
        ("fractional reps", set(#"{ "weight": 60, "reps": 8.5 }"#)),
        ("weight as text", set(#"{ "weight": "60", "reps": 8 }"#)),
        ("exercise without id or name", exercise(#"{ "sets": [] }"#)),
        ("blank exercise name", exercise(#"{ "exerciseName": " " }"#)),
        ("dotted date", session(#""date": "28.09.2026""#)),
        ("time without zone", session(#""startedAt": "2026-09-28T18:00:00""#)),
        ("unknown status", session(#""status": "done""#)),
        ("pounds spelled out", #"{ "units": { "weight": "pounds" }, "sessions": [] }"#),
        ("weekdays without days", schedule(#"{ "type": "weekdays" }"#)),
        ("interval with days", schedule(#"{ "type": "interval", "everyDays": 2, "days": ["mon"] }"#)),
        ("repeated day", schedule(#"{ "type": "weekdays", "days": ["mon", "mon"] }"#)),
        ("zero increment", #"{ "exercises": [ { "name": "Row", "incrementKg": 0 } ], "sessions": [] }"#),
    ])
    func brokenFilesAreRejected(_ problem: String, _ json: String) throws {
        #expect(try !validator.errors(in: Data(json.utf8)).isEmpty, "\(problem)")
    }

    @Test func dateMustExist() {
        #expect(LocalDate("2026-09-28") == LocalDate(year: 2026, month: 9, day: 28))
        #expect(LocalDate("2026-02-30") == nil)
        #expect(LocalDate("2026-9-28") == nil)
        #expect(throws: DecodingError.self) {
            try PeakJSON.decode(Data(#"{ "sessions": [ { "date": "2026-02-30", "exercises": [] } ] }"#.utf8))
        }
    }

    @Test func timestampsReadWithOrWithoutFractionAndOffset() throws {
        let json = #"""
            { "sessions": [
              { "startedAt": "2026-09-30T16:00:00Z", "endedAt": "2026-09-30T19:00:00.500+03:00", "exercises": [] }
            ] }
            """#
        let session = try PeakJSON.decode(Data(json.utf8)).sessions[0]
        let start = try #require(session.startedAt)
        let end = try #require(session.endedAt)
        #expect(end.timeIntervalSince(start) == 0.5)
    }

    // MARK: Helpers

    /// "sessions.exercises.sets.weight"-style paths of every key in a JSON document (array indexes dropped).
    static func keyPaths(_ data: Data) throws -> Set<String> {
        var paths: Set<String> = []
        func walk(_ value: Any, _ prefix: String) {
            if let object = value as? [String: Any] {
                for (key, child) in object {
                    let path = prefix.isEmpty ? key : "\(prefix).\(key)"
                    paths.insert(path)
                    walk(child, path)
                }
            } else if let array = value as? [Any] {
                for item in array { walk(item, prefix) }
            }
        }
        walk(try JSONSerialization.jsonObject(with: data), "")
        return paths
    }

    /// Names under every `properties` keyword in a schema.
    static func propertyNames(in value: Any) -> Set<String> {
        if let object = value as? [String: Any] {
            let own = Set((object["properties"] as? [String: Any] ?? [:]).keys)
            return object.values.reduce(into: own) { $0.formUnion(propertyNames(in: $1)) }
        }
        if let array = value as? [Any] {
            return array.reduce(into: []) { $0.formUnion(propertyNames(in: $1)) }
        }
        return []
    }
}
