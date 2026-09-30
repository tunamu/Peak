import Foundation

/// A small JSON Schema (2020-12) validator for the keywords Peak's schema uses, so tests need no dependency.
/// An unsupported keyword is reported as an error rather than skipped, so a schema change cannot silently weaken the
/// tests. The schema was also checked once with Ajv in strict mode (docs/schema/README.md).
struct JSONSchemaValidator {
    let root: [String: Any]

    init(schema data: Data) throws {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CocoaError(.coderReadCorrupt)
        }
        self.root = root
    }

    /// Error messages as "path: problem"; empty when `document` is valid.
    func errors(in document: Data) throws -> [String] {
        let value = try JSONSerialization.jsonObject(with: document, options: .fragmentsAllowed)
        return validate(value, against: root, at: "$")
    }

    private static let annotations: Set = ["$schema", "$id", "title", "description", "format"]

    private func validate(_ value: Any, against schema: [String: Any], at path: String) -> [String] {
        var errors: [String] = []
        for (keyword, rule) in schema where !Self.annotations.contains(keyword) {
            errors += check(keyword, rule, value, schema, path)
        }
        return errors
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func check(_ keyword: String, _ rule: Any, _ value: Any, _ schema: [String: Any], _ path: String)
        -> [String]
    {
        switch keyword {
        case "$defs":
            return []
        case "$ref":
            guard let ref = rule as? String, let target = resolve(ref) else { return ["\(path): bad $ref \(rule)"] }
            return validate(value, against: target, at: path)
        case "type":
            return Self.matches(value, type: rule as? String ?? "") ? [] : ["\(path): expected \(rule)"]
        case "const":
            return Self.equal(value, rule) ? [] : ["\(path): expected \(rule)"]
        case "enum":
            let options = rule as? [Any] ?? []
            return options.contains { Self.equal(value, $0) } ? [] : ["\(path): \(value) not in \(options)"]
        case "required":
            guard let object = value as? [String: Any] else { return [] }
            return (rule as? [String] ?? []).filter { object[$0] == nil }.map { "\(path): missing \($0)" }
        case "properties":
            guard let object = value as? [String: Any], let properties = rule as? [String: [String: Any]] else {
                return []
            }
            return properties.flatMap { key, subschema in
                object[key].map { validate($0, against: subschema, at: "\(path).\(key)") } ?? []
            }
        case "additionalProperties":
            guard let object = value as? [String: Any], rule as? Bool == false else { return [] }
            let known = Set((schema["properties"] as? [String: Any] ?? [:]).keys)
            return object.keys.filter { !known.contains($0) }.sorted().map { "\(path): unknown property \($0)" }
        case "items":
            guard let array = value as? [Any], let subschema = rule as? [String: Any] else { return [] }
            return array.enumerated().flatMap { validate($1, against: subschema, at: "\(path)[\($0)]") }
        case "minItems":
            guard let array = value as? [Any] else { return [] }
            return array.count >= rule as? Int ?? 0 ? [] : ["\(path): fewer than \(rule) items"]
        case "uniqueItems":
            guard let array = value as? [Any], rule as? Bool == true else { return [] }
            let unique = array.enumerated().allSatisfy { index, item in
                !array[..<index].contains { Self.equal($0, item) }
            }
            return unique ? [] : ["\(path): duplicate items"]
        case "minLength":
            guard let string = value as? String else { return [] }
            return string.count >= rule as? Int ?? 0 ? [] : ["\(path): shorter than \(rule)"]
        case "pattern":
            guard let string = value as? String else { return [] }
            let matches = (try? Regex(rule as? String ?? "")).map { string.contains($0) } ?? false
            return matches ? [] : ["\(path): \"\(string)\" does not match \(rule)"]
        case "minimum", "exclusiveMinimum":
            guard let number = Self.number(value), let bound = Self.number(rule) else { return [] }
            let valid = keyword == "minimum" ? number >= bound : number > bound
            return valid ? [] : ["\(path): \(number) breaks \(keyword) \(bound)"]
        case "anyOf", "oneOf":
            let passing = (rule as? [[String: Any]] ?? []).filter { validate(value, against: $0, at: path).isEmpty }
            let valid = keyword == "anyOf" ? !passing.isEmpty : passing.count == 1
            return valid ? [] : ["\(path): \(passing.count) of the \(keyword) schemas match"]
        default:
            return ["\(path): unsupported keyword \(keyword)"]
        }
    }

    private func resolve(_ ref: String) -> [String: Any]? {
        guard ref.hasPrefix("#/") else { return nil }
        var node: Any = root
        for part in ref.dropFirst(2).split(separator: "/") {
            guard let object = node as? [String: Any], let next = object[String(part)] else { return nil }
            node = next
        }
        return node as? [String: Any]
    }

    private static func isBool(_ value: Any) -> Bool {
        guard let number = value as? NSNumber else { return false }
        return CFGetTypeID(number) == CFBooleanGetTypeID()
    }

    private static func number(_ value: Any) -> Double? {
        guard !isBool(value), let number = value as? NSNumber else { return nil }
        return number.doubleValue
    }

    private static func matches(_ value: Any, type: String) -> Bool {
        switch type {
        case "object": value is [String: Any]
        case "array": value is [Any]
        case "string": value is String
        case "boolean": isBool(value)
        case "number": number(value) != nil
        case "integer": number(value).map { $0.rounded() == $0 } ?? false
        case "null": value is NSNull
        default: false
        }
    }

    private static func equal(_ lhs: Any, _ rhs: Any) -> Bool {
        if isBool(lhs) != isBool(rhs) { return false }
        return (lhs as? NSObject)?.isEqual(rhs) ?? false
    }
}
