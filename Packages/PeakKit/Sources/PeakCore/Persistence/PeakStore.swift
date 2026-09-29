import Foundation
import SwiftData

/// Every schema version and the steps between them. Only `SchemaV1` exists so far.
public enum PeakMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}

/// Builds the app's `ModelContainer`.
public enum PeakStore {
    /// Shared with the widget extension, so both open the same store.
    public static let appGroupID = "group.com.tunamu.peak"
    public static let cloudKitContainerID = "iCloud.com.tunamu.peak"

    public static var schema: Schema { Schema(versionedSchema: SchemaV1.self) }

    public enum Location: Sendable {
        /// The App Group container: the app and the widget see the same data.
        case appGroup
        /// Memory only, for tests and previews.
        case inMemory
    }

    /// - Parameters:
    ///   - location: Where the store lives.
    ///   - syncsWithCloudKit: Off until iCloud sync (F8). SwiftData's default would sync as soon as the app has an
    ///     iCloud entitlement, so this is always passed explicitly.
    public static func makeContainer(
        _ location: Location = .appGroup,
        syncsWithCloudKit: Bool = false
    ) throws -> ModelContainer {
        let configuration: ModelConfiguration
        switch location {
        case .appGroup:
            configuration = ModelConfiguration(
                "Peak",
                schema: schema,
                groupContainer: .identifier(appGroupID),
                cloudKitDatabase: syncsWithCloudKit ? .private(cloudKitContainerID) : .none
            )
        case .inMemory:
            configuration = ModelConfiguration(
                "Peak",
                schema: schema,
                isStoredInMemoryOnly: true,
                groupContainer: .none,
                cloudKitDatabase: .none
            )
        }
        return try ModelContainer(
            for: schema,
            migrationPlan: PeakMigrationPlan.self,
            configurations: configuration
        )
    }
}
