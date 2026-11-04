import Foundation
import SwiftData
import TimelineEngine

/// Schéma courant (lots 12 et 13, ADR-016). Par rapport à la v2 : l'espace d'une capture
/// (`spaceRaw`), les sous-tâches (`subtasksRaw`), les champs du modèle de section (`fieldsRaw`) et
/// le modèle d'une section (`templateRaw`). Champs facultatifs seulement : migration légère.
/// Champs alignés sur le backend (`backend/app/models.py`).
public enum SchemaV3: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(3, 0, 0) }
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
        /// `TaskSpace` d'une capture sans section ; `nil` : la boîte de réception.
        public var spaceRaw: String?
        /// Sous-tâches, en JSON (`[Subtask]`) : elles vivent et se synchronisent avec la tâche.
        public var subtasksRaw: String?
        /// Champs du modèle de la section (genre, lieu, ingrédients…), en JSON (`[String: String]`).
        public var fieldsRaw: String?

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
            self.spaceRaw = nil
            self.subtasksRaw = nil
            self.fieldsRaw = nil
        }
    }

    /// Section, avec ses règles (ADR-014), son type (ADR-015) et son modèle (ADR-016).
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
        /// `SectionTemplate` ; `nil` pour une section à faire ou d'avant la v3 : déduit du type et du nom.
        public var templateRaw: String?

        public init(id: UUID = UUID(), name: String, symbol: String, sortIndex: Int,
                    defaultDuration: Int?, isPlannable: Bool, keepsMemory: Bool,
                    repeatRule: SectionRepeat, kind: SectionKind? = nil, template: SectionTemplate? = nil,
                    now: Date) {
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
            self.templateRaw = template?.rawValue
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
    public static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self, SchemaV3.self] }
    /// Chaque étape n'ajoute que des champs facultatifs : migrations légères.
    public static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self),
            .lightweight(fromVersion: SchemaV2.self, toVersion: SchemaV3.self),
        ]
    }
}

public typealias TaskItem = SchemaV3.TaskItem
public typealias WorkSession = SchemaV3.WorkSession
public typealias TaskSection = SchemaV3.TaskSection
