import CoreData
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
        /// A file at the given URL, for tests that close and reopen the store.
        case file(URL)
    }

    /// - Parameters:
    ///   - location: Where the store lives.
    ///   - syncsWithCloudKit: On only in the app (F8). The widget opens the same store without sync, and SwiftData's
    ///     default would sync as soon as a target has an iCloud entitlement, so this is always passed explicitly.
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
        case .file(let url):
            configuration = ModelConfiguration(
                schema: schema,
                url: url,
                cloudKitDatabase: .none
            )
        }
        return try ModelContainer(
            for: schema,
            migrationPlan: PeakMigrationPlan.self,
            configurations: configuration
        )
    }

    #if DEBUG
        /// Creates every record type in the CloudKit development environment, including models that have no data
        /// yet, so the whole schema can be deployed to production (CloudKit Console). Sync alone only creates the
        /// types it has uploaded. Uses a throwaway store: the app's data is not touched. Blocks until CloudKit
        /// answers, so call it off the main actor.
        public static func initializeCloudKitSchema() throws {
            guard let model = NSManagedObjectModel.makeManagedObjectModel(for: SchemaV1.models) else {
                throw CocoaError(.coreData)
            }
            let directory = FileManager.default.temporaryDirectory
                .appending(path: "PeakSchema-\(UUID().uuidString)", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: directory) }

            let description = NSPersistentStoreDescription(url: directory.appending(path: "Schema.store"))
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: cloudKitContainerID
            )
            description.shouldAddStoreAsynchronously = false
            let container = NSPersistentCloudKitContainer(name: "PeakSchema", managedObjectModel: model)
            container.persistentStoreDescriptions = [description]
            var loadError: (any Error)?
            container.loadPersistentStores { _, error in loadError = error }
            if let loadError { throw loadError }
            try container.initializeCloudKitSchema()
            for store in container.persistentStoreCoordinator.persistentStores {
                try container.persistentStoreCoordinator.remove(store)
            }
        }
    #endif
}
