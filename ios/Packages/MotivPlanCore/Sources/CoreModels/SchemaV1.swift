import Foundation
import SwiftData
import TimelineEngine

/// Schéma versionné dès le premier commit (plan, principes d'architecture).
/// Champs alignés sur le backend (`backend/app/models.py`). Les enums sont stockés en chaînes :
/// les prédicats SwiftData sur des enums sont fragiles, les chaînes passent partout.
public enum SchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    public static var models: [any PersistentModel.Type] { [TaskItem.self, WorkSession.self] }

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
        public var categoryRaw: String?
        public var importanceRaw: String?
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

        public init(id: UUID = UUID(), title: String, source: TaskSource, now: Date) {
            self.id = id
            self.createdAt = now
            self.updatedAt = now
            self.deletedAt = nil
            self.needsSync = true
            self.title = title
            self.notes = nil
            self.categoryRaw = nil
            self.importanceRaw = nil
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
    public static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}

public typealias TaskItem = SchemaV1.TaskItem
public typealias WorkSession = SchemaV1.WorkSession

extension TaskItem {
    public var status: TaskStatus {
        TaskStatus(rawValue: statusRaw) ?? .inbox
    }

    public var category: TaskCategory? {
        categoryRaw.flatMap(TaskCategory.init(rawValue:))
    }

    public var importance: Importance? {
        importanceRaw.flatMap(Importance.init(rawValue:))
    }

    public var source: TaskSource {
        TaskSource(rawValue: sourceRaw) ?? .manual
    }

    public var isDone: Bool { status == .done }

    /// Échéance dépassée : signalée sobrement, jamais en rouge (principe 2).
    public func isOverdue(today: DayKey) -> Bool {
        guard let dueDate, status != .done else { return false }
        return dueDate < today
    }

    /// Vue moteur de la tâche, si elle a une place dans un jour.
    public var timelineItem: TimelineItem? {
        guard let orderIndex else { return nil }
        return TimelineItem(id: id, orderIndex: orderIndex,
                            durationMin: durationMin ?? Durations.fallback,
                            anchorStart: isAnchored ? anchorTime : nil)
    }

    /// Boîte de réception, la capture la plus récente en tête. Pour `@Query`.
    public static var inboxDescriptor: FetchDescriptor<TaskItem> {
        let inbox = TaskStatus.inbox.rawValue
        return FetchDescriptor(
            predicate: #Predicate { $0.deletedAt == nil && $0.statusRaw == inbox },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
    }
}
