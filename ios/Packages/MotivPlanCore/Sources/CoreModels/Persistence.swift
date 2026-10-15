import Foundation
import SwiftData

public enum Persistence {
    /// Configuration toujours explicite : App Group, sans CloudKit (ADR-006).
    /// `inMemory` sert aux tests et aux captures d'écran automatiques.
    ///
    /// Repli : une installation par SideStore ou AltStore (ADR-013) renomme ou retire l'App Group.
    /// Sans conteneur de groupe, le store va dans l'espace propre de l'app ; seul l'app y écrit
    /// (ADR-006) et le widget ne lit rien, donc rien ne se perd.
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            groupContainer: inMemory || !AppGroup.isAvailable ? .none : .identifier(AppGroup.identifier),
            cloudKitDatabase: .none)
        return try ModelContainer(for: schema, migrationPlan: MotivPlanMigrationPlan.self,
                                  configurations: [configuration])
    }
}
