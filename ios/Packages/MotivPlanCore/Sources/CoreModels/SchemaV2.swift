import Foundation
import SwiftData
import TimelineEngine

/// Schéma courant (lot 11, ADR-015). Par rapport à la v1 : le type d'une section (`kindRaw`) et les
/// dates d'une période (`startDate`, `endDate`). Champs facultatifs seulement : la migration depuis
/// la v1 est légère, rien n'est recopié. Champs alignés sur le backend (`backend/app/models.py`).
public enum SchemaV2: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }
    public static var models: [any PersistentModel.Type] { [TaskItem.self, TaskSection.self, WorkSession.self] }

    /// Tâche (`Task` du cahier ; renommée pour éviter la collision avec Swift Concurrency).
    /// Ne s'écrit que par `TaskStore`.
    @Model
    public final class TaskItem {
        @Attribute(.unique) public var id: UUID
        public var createdAt: Date
        public var updatedAt: Date
        public var deletedAt: Date?
        public var needsSync: Bool

        public var title: String
        public var notes: String?
        /// `nil` : « À trier » (capture sans section).
        public var sectionId: UUID?
        public var tagRaw: String?
        /// Clé-jour `yyyy-MM-dd`.
        public var dueDate: String?
        public var durationMin: Int?
        public var statusRaw: String
        /// Clé-jour `yyyy-MM-dd`.
        public var scheduledDate: String?
        public var orderIndex: Int?
        public var isAnchored: Bool
        /// Minutes depuis minuit.
        public var anchorTime: Int?
        public var completedAt: Date?
        public var postponeCount: Int
        public var sourceRaw: String
        /// Avis d'un élément de mémoire (section `keepsMemory`).
        public var reviewRaw: String?
        public var reviewNote: String?
        /// Période (section de type `periods`) : premier et dernier jour inclus, clés `yyyy-MM-dd`.
        /// Une période ne se pose jamais dans la journée : elle s'affiche dans le calendrier.
        public var startDate: String?
        public var endDate: String?

        public init(id: UUID = UUID(), title: String, source: TaskSource, now: Date) {
            self.id = id
            self.createdAt = now
            self.updatedAt = now
            self.deletedAt = nil
            self.needsSync = true
            self.title = title
            self.notes = nil
            self.sectionId = nil
            self.tagRaw = nil
            self.dueDate = nil
            self.durationMin = nil
            self.statusRaw = TaskStatus.inbox.rawValue
            self.scheduledDate = nil
            self.orderIndex = nil
            self.isAnchored = false
            self.anchorTime = nil
            self.completedAt = nil
            self.postponeCount = 0
            self.sourceRaw = source.rawValue
            self.reviewRaw = nil
            self.reviewNote = nil
            self.startDate = nil
            self.endDate = nil
        }
    }

    /// Section, avec ses règles (ADR-014) et son type (ADR-015).
    @Model
    public final class TaskSection {
        @Attribute(.unique) public var id: UUID
        public var createdAt: Date
        public var updatedAt: Date
        public var deletedAt: Date?
        public var needsSync: Bool

        public var name: String
        /// Nom d'un symbole SF Symbols.
        public var symbol: String
        public var sortIndex: Int
        /// Durée suggérée au dépôt dans la journée.
        public var defaultDuration: Int?
        /// Visible dans le tiroir et posable dans la journée.
        public var isPlannable: Bool
        /// Une tâche terminée reste consultable, avec son avis.
        public var keepsMemory: Bool
        public var repeatRaw: String
        /// `SectionKind` ; `nil` pour une section créée avant la v2 : le type se déduit de ses règles.
        public var kindRaw: String?

        public init(id: UUID = UUID(), name: String, symbol: String, sortIndex: Int,
                    defaultDuration: Int?, isPlannable: Bool, keepsMemory: Bool,
                    repeatRule: SectionRepeat, kind: SectionKind? = nil, now: Date) {
            self.id = id
            self.createdAt = now
            self.updatedAt = now
            self.deletedAt = nil
            self.needsSync = true
            self.name = name
            self.symbol = symbol
            self.sortIndex = sortIndex
            self.defaultDuration = defaultDuration
            self.isPlannable = isPlannable
            self.keepsMemory = keepsMemory
            self.repeatRaw = repeatRule.rawValue
            self.kindRaw = kind?.rawValue
        }
    }

    /// `Session` du cahier : présente dès la v1, sans interface avant la v2.
    @Model
    public final class WorkSession {
        @Attribute(.unique) public var id: UUID
        public var createdAt: Date
        public var updatedAt: Date
        public var deletedAt: Date?
        public var needsSync: Bool

        public var taskId: UUID
        public var scheduledDate: String
        public var orderIndex: Int
        public var durationMin: Int
        public var completedAt: Date?

        public init(id: UUID = UUID(), taskId: UUID, scheduledDate: String, orderIndex: Int,
                    durationMin: Int, now: Date) {
            self.id = id
            self.createdAt = now
            self.updatedAt = now
            self.deletedAt = nil
            self.needsSync = true
            self.taskId = taskId
            self.scheduledDate = scheduledDate
            self.orderIndex = orderIndex
            self.durationMin = durationMin
            self.completedAt = nil
        }
    }
}

public enum MotivPlanMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self] }
    /// v1 → v2 : trois champs facultatifs ajoutés, migration légère.
    public static var stages: [MigrationStage] {
        [.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)]
    }
}

public typealias TaskItem = SchemaV2.TaskItem
public typealias WorkSession = SchemaV2.WorkSession
public typealias TaskSection = SchemaV2.TaskSection
