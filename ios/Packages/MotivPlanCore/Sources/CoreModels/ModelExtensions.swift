import Foundation
import SwiftData
import TimelineEngine

// Lecture des modèles courants (`SchemaV2`) : énumérations, vues moteur, requêtes `@Query`.

extension TaskSection {
    public var repeatRule: SectionRepeat {
        SectionRepeat(rawValue: repeatRaw) ?? .none
    }

    public var kind: SectionKind {
        kindRaw.flatMap(SectionKind.init(rawValue:))
            ?? SectionKind.inferred(name: name, isPlannable: isPlannable, keepsMemory: keepsMemory)
    }

    /// Ses tâches apparaissent dans le tiroir et se posent dans la journée. Un élément de mémoire
    /// peut aussi être planifié, mais seulement par son bouton « Planifier ».
    public var isDayPlannable: Bool { kind == .tasks && isPlannable }

    /// Sections non supprimées, dans l'ordre choisi. Pour `@Query`.
    public static var orderedDescriptor: FetchDescriptor<TaskSection> {
        FetchDescriptor(predicate: #Predicate { $0.deletedAt == nil },
                        sortBy: [SortDescriptor(\.sortIndex)])
    }
}

extension TaskItem {
    public var status: TaskStatus {
        TaskStatus(rawValue: statusRaw) ?? .inbox
    }

    public var tag: TaskTag? {
        tagRaw.flatMap(TaskTag.init(rawValue:))
    }

    public var review: Review? {
        reviewRaw.flatMap(Review.init(rawValue:))
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

    /// À faire, en boîte ou posées sur un jour sans être faites : une tuile de section les compte
    /// toutes (une quotidienne posée seule reste visible dans sa section).
    public static var openDescriptor: FetchDescriptor<TaskItem> {
        let inbox = TaskStatus.inbox.rawValue
        let scheduled = TaskStatus.scheduled.rawValue
        return FetchDescriptor(
            predicate: #Predicate { $0.deletedAt == nil && ($0.statusRaw == inbox || $0.statusRaw == scheduled) },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
    }

    /// Vue moteur pour le report automatique.
    public var rolloverTask: RolloverTask {
        RolloverTask(id: id, status: status, scheduledDate: scheduledDate, orderIndex: orderIndex,
                     anchorStart: isAnchored ? anchorTime : nil, dueDate: dueDate,
                     postponeCount: postponeCount)
    }

    /// Tâches posées sur un jour (statut filtré ensuite : `isOnDay`), dans l'ordre stocké.
    public static func dayDescriptor(_ day: DayKey) -> FetchDescriptor<TaskItem> {
        let target: String? = day
        return FetchDescriptor(
            predicate: #Predicate { $0.deletedAt == nil && $0.scheduledDate == target },
            sortBy: [SortDescriptor(\.orderIndex)])
    }

    /// Posée sur un jour, faite ou non : une tâche faite garde sa place (cahier §4.4).
    public var isOnDay: Bool { status == .scheduled || status == .done }

    /// Dernier jour d'une période (le premier si la fin manque).
    public var periodEnd: DayKey? { endDate ?? startDate }

    /// La période touche l'intervalle de jours donné (bornes incluses).
    public func overlaps(from start: DayKey, through end: DayKey) -> Bool {
        guard let startDate, let periodEnd else { return false }
        return startDate <= end && periodEnd >= start
    }

    /// Éléments datés d'une période, du plus proche au plus lointain. Pour `@Query`.
    public static var periodDescriptor: FetchDescriptor<TaskItem> {
        FetchDescriptor(predicate: #Predicate { $0.deletedAt == nil && $0.startDate != nil },
                        sortBy: [SortDescriptor(\.startDate)])
    }
}
