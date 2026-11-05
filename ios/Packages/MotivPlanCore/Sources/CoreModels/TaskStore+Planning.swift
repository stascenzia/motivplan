import Foundation
import SwiftData
import TimelineEngine

/// Quotidiennes dans le tiroir, répétitions, « Vider la journée » (ADR-018).
extension TaskStore {
    // MARK: Répétition

    /// Répétition de la planification ; `nil` la retire. La tâche garde son jour actuel : la
    /// répétition joue quand ce jour est passé.
    public func setRepeat(_ rule: TaskRepeat?, of task: TaskItem) throws {
        try setField(TaskItem.repeatField, to: rule?.rawValue, of: task)
    }

    /// Repose une tâche répétée sur sa prochaine date : non cochée, étapes remises à faire, sans
    /// compter de report.
    func reschedule(_ task: TaskItem, on day: DayKey) throws {
        task.completedAt = nil
        task.statusRaw = TaskStatus.scheduled.rawValue
        let subtasks = task.subtasks
        if subtasks.contains(where: \.isDone) {
            task.subtasksRaw = Self.encode(subtasks.map { Subtask(id: $0.id, title: $0.title) })
        }
        try schedule(task, on: day)
    }

    // MARK: Quotidiennes

    /// Remet une quotidienne dans le tiroir, non cochée. Son heure fixe est gardée : reposée, elle
    /// reprend sa place.
    func releaseToDrawer(_ task: TaskItem) {
        task.statusRaw = TaskStatus.inbox.rawValue
        task.scheduledDate = nil
        task.orderIndex = nil
        task.completedAt = nil
        touch(task)
    }

    public static let dailiesReleasedKey = "migration.dailiesInDrawer"

    /// Une seule fois, au premier lancement de cette version : les quotidiennes posées seules
    /// aujourd'hui ou plus tard, pas encore faites, retournent dans le tiroir. Répare aussi une section
    /// de voyages rangée comme simple liste (ses éléments n'avaient ni dates ni lieu).
    /// - Returns: le nombre de quotidiennes retirées de la journée.
    @discardableResult
    public func releaseAutoPlacedDailies(defaults: UserDefaults = AppGroup.defaults) throws -> Int {
        guard !defaults.bool(forKey: Self.dailiesReleasedKey) else { return 0 }
        let daily = Set(try sections().filter { $0.repeatRule == .daily }.map(\.id))
        let all = try context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.deletedAt == nil }))
        let today = self.today
        var days = Set<DayKey>()
        var released = 0
        for task in all where task.sectionId.map(daily.contains) == true && task.status == .scheduled {
            guard let day = task.scheduledDate, day >= today else { continue }
            days.insert(day)
            releaseToDrawer(task)
            released += 1
        }
        for day in days {
            try normalizeDay(day)
        }
        try repairTripSections()
        try save()
        defaults.set(true, forKey: Self.dailiesReleasedKey)
        return released
    }

    /// Une section au nom de voyage, rangée en « Mémoire avec avis » sans modèle choisi, devient une
    /// section de voyages : dates, lieu, bandeau dans le calendrier.
    func repairTripSections() throws {
        for section in try sections() where section.kind == .memory && SectionKind.isTripName(section.name) {
            guard section.templateRaw == nil || section.templateRaw == SectionTemplate.liste.rawValue else { continue }
            section.kindRaw = SectionKind.periods.rawValue
            section.templateRaw = SectionTemplate.voyage.rawValue
            section.keepsMemory = false
            section.isPlannable = false
            touch(section)
        }
    }

    // MARK: Vider la journée

    /// Ce que « Vider la journée » a déplacé, pour pouvoir l'annuler.
    public struct DayClearing: Sendable, Equatable {
        public struct Entry: Sendable, Equatable {
            let id: UUID
            let orderIndex: Int?
            let isAnchored: Bool
            let anchorTime: Int?
        }

        public let day: DayKey
        let entries: [Entry]

        public var count: Int { entries.count }
    }

    /// Remet dans la boîte toutes les tâches non faites du jour ; les quotidiennes retournent dans
    /// le tiroir. Les tâches faites restent.
    @discardableResult
    public func clearDay(_ day: DayKey) throws -> DayClearing {
        let daily = Set(try sections().filter { $0.repeatRule == .daily }.map(\.id))
        let open = try tasks(on: day).filter { $0.status == .scheduled }
        let entries = open.map { DayClearing.Entry(id: $0.id, orderIndex: $0.orderIndex,
                                                   isAnchored: $0.isAnchored, anchorTime: $0.anchorTime) }
        for task in open {
            if task.sectionId.map(daily.contains) == true {
                releaseToDrawer(task)
            } else {
                task.statusRaw = TaskStatus.inbox.rawValue
                task.scheduledDate = nil
                task.orderIndex = nil
                task.isAnchored = false
                task.anchorTime = nil
                touch(task)
            }
        }
        try normalizeDay(day)
        try save()
        return DayClearing(day: day, entries: entries)
    }

    /// Annule « Vider la journée » : chaque tâche encore en boîte reprend sa place et son heure.
    public func restore(_ clearing: DayClearing) throws {
        let ids = clearing.entries.map(\.id)
        let tasks = try context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { ids.contains($0.id) }))
        let byId = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
        for entry in clearing.entries {
            guard let task = byId[entry.id], task.deletedAt == nil, task.status == .inbox else { continue }
            task.statusRaw = TaskStatus.scheduled.rawValue
            task.scheduledDate = clearing.day
            task.orderIndex = entry.orderIndex
            task.isAnchored = entry.isAnchored
            task.anchorTime = entry.anchorTime
            touch(task)
        }
        try normalizeDay(clearing.day)
        try save()
    }
}
