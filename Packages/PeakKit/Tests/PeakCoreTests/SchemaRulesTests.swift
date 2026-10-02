import Foundation
import PeakCore
import SwiftData
import Testing

/// The CloudKit rules from docs/DATA_MODEL.md, checked on the real schema so a new property cannot break sync later.
@Suite struct SchemaRulesTests {
    static let entities = PeakStore.schema.entities

    @Test func schemaHasEveryModel() {
        #expect(Self.entities.count == SchemaV2.models.count)
    }

    @Test func noUniqueConstraints() {
        for entity in Self.entities {
            for property in entity.storedProperties {
                #expect(!property.isUnique, "\(entity.name).\(property.name) is unique")
            }
        }
    }

    @Test func attributesHaveDefaultsOrAreOptional() {
        for entity in Self.entities {
            for attribute in entity.attributes {
                #expect(
                    attribute.isOptional || attribute.defaultValue != nil,
                    "\(entity.name).\(attribute.name) needs a default value or must be optional"
                )
            }
        }
    }

    @Test func relationshipsAreOptionalWithInverse() {
        for entity in Self.entities {
            for relationship in entity.relationships {
                #expect(relationship.isOptional, "\(entity.name).\(relationship.name) must be optional")
                #expect(relationship.inverseName != nil, "\(entity.name).\(relationship.name) needs an inverse")
            }
        }
    }

    @Test func attributesUseCloudKitFriendlyTypes() {
        let allowed: [Any.Type] = [
            String.self, Int.self, Double.self, Bool.self, Date.self, UUID.self,
            String?.self, Int?.self, Double?.self, Date?.self, UUID?.self,
            // A type literal, not an optional-Bool value.
            Bool?.self,  // swiftlint:disable:this discouraged_optional_boolean
        ]
        for entity in Self.entities {
            for attribute in entity.attributes {
                let isAllowed = allowed.contains { $0 == attribute.valueType }
                #expect(isAllowed, "\(entity.name).\(attribute.name) is \(attribute.valueType); store enums as String")
            }
        }
    }

    @MainActor @Test func inMemoryContainerOpens() throws {
        let container = try PeakStore.makeContainer(.inMemory)
        let context = container.mainContext
        context.insert(Exercise(name: "Row"))
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Exercise>()) == 1)
    }
}
