import Foundation
import SwiftData
import TimelineEngine

// Lecture des modèles courants (`SchemaV3`) : énumérations, vues moteur, requêtes `@Query`.

extension TaskSection {
    public var repeatRule: SectionRepeat {
        SectionRepeat(rawValue: repeatRaw) ?? .none
    }

    public var kind: SectionKind {
        kindRaw.flatMap(SectionKind.init(rawValue:))
            ?? SectionKind.inferred(name: name, isPlannable: isPlannable, keepsMemory: keepsMemory)
    }

    /// Modèle d'une section de la Mémoire (ADR-016) ; `nil` pour une section à faire.
    public var template: SectionTemplate? {
        guard kind.isMemorySpace else { return nil }
        // Une liste nommée « Valise » sans modèle propre (liste simple, courses) devient une valise.
        let stored = templateRaw.flatMap(SectionTemplate.init(rawValue:))
        if stored == .valise { return .valise }
        if kind != .periods, SectionTemplate.isSuitcaseName(name), stored == nil || stored == .liste || stored == .courses {
            return .valise
        }
        if let stored, stored.kind == kind { return stored }
        return SectionTemplate.inferred(kind: kind, name: name)
    }

    /// Terminer un élément ouvre l'avis : une section à faire qui garde la mémoire, ou un modèle
    /// qui le demande (films, recettes, voyages).
    public var asksReview: Bool {
        if let template { return template.asksReview }
        return keepsMemory
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

    /// Étiquette principale, la plus prioritaire : elle donne sa couleur à la tâche.
    public var tag: TaskTag? {
        tagRaw.flatMap(TaskTag.init(rawValue:))
    }

    /// Toutes les étiquettes, de la plus prioritaire à la moins prioritaire (ADR-018). La première
    /// reste dans `tagRaw` ; la liste complète vit dans les champs (`tags`), synchronisés tels quels.
    public var tags: [TaskTag] {
        let listed = (fields[Self.tagsField] ?? "").split(separator: ",")
            .compactMap { TaskTag(rawValue: String($0)) }
        let all = listed.isEmpty ? (tag.map { [$0] } ?? []) : listed
        return TaskTag.allCases.filter(all.contains)
    }

    /// Répétition de la planification (ADR-018).
    public var taskRepeat: TaskRepeat? {
        fields[Self.repeatField].flatMap(TaskRepeat.init(rawValue:))
    }

    public static let tagsField = "tags"
    public static let repeatField = "repeat"

    public var review: Review? {
        reviewRaw.flatMap(Review.init(rawValue:))
    }

    public var source: TaskSource {
        TaskSource(rawValue: sourceRaw) ?? .manual
    }

    public var isDone: Bool { status == .done }

    /// Espace d'une capture sans section (ADR-016). Une entrée rangée suit sa section.
    public var space: TaskSpace {
        spaceRaw.flatMap(TaskSpace.init(rawValue:)) ?? .tasks
    }

    /// « À trier » de la boîte de réception : capture sans section, hors Mémoire.
    public var isUnsortedTask: Bool { sectionId == nil && space == .tasks }

    /// « À trier » de la Mémoire.
    public var isUnsortedMemory: Bool { sectionId == nil && space == .memory }

    /// Sous-tâches dans l'ordre (ADR-016). Vide si la tâche n'est pas découpée.
    public var subtasks: [Subtask] {
        guard let data = subtasksRaw?.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([Subtask].self, from: data)) ?? []
    }

    /// Champs du modèle de la section : genre, plateforme, lieu, ingrédients…
    public var fields: [String: String] {
        guard let data = fieldsRaw?.data(using: .utf8) else { return [:] }
        return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
    }

    public func field(_ key: String) -> String? {
        fields[key]
    }

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
    /// toutes (une quotidienne posée reste visible dans sa section).
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

    /// Tout ce qui est rangé dans une section, fait ou non, le plus récent en tête (onglet Mémoire).
    public static var sectionedDescriptor: FetchDescriptor<TaskItem> {
        FetchDescriptor(predicate: #Predicate { $0.deletedAt == nil && $0.sectionId != nil },
                        sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
    }

    /// Éléments datés d'une période, du plus proche au plus lointain. Pour `@Query`.
    public static var periodDescriptor: FetchDescriptor<TaskItem> {
        FetchDescriptor(predicate: #Predicate { $0.deletedAt == nil && $0.startDate != nil },
                        sortBy: [SortDescriptor(\.startDate)])
    }
}
