import Foundation
import SwiftData
import TimelineEngine

/// Schéma versionné dès le premier commit (plan, principes d'architecture). Figé depuis la v2 :
/// il décrit les stores déjà installés et sert de point de départ à la migration (`SchemaV2`).
/// Champs alignés sur le backend (`backend/app/models.py`). Les enums sont stockés en chaînes :
/// les prédicats SwiftData sur des enums sont fragiles, les chaînes passent partout.
public enum SchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
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
        }
    }

    /// Section de la boîte de réception, avec ses règles (ADR-014).
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

        public init(id: UUID = UUID(), name: String, symbol: String, sortIndex: Int,
                    defaultDuration: Int?, isPlannable: Bool, keepsMemory: Bool,
                    repeatRule: SectionRepeat, now: Date) {
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
