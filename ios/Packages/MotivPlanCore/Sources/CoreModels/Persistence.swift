import Foundation
import SwiftData

public enum Persistence {
    /// Configuration toujours explicite : App Group, sans CloudKit (ADR-006).
    /// `inMemory` sert aux tests et aux captures d'écran automatiques.
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            groupContainer: inMemory ? .none : .identifier(AppGroup.identifier),
            cloudKitDatabase: .none)
        return try ModelContainer(for: schema, migrationPlan: MotivPlanMigrationPlan.self,
                                  configurations: [configuration])
    }
}
