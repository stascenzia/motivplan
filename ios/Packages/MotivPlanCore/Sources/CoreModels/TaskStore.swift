import Foundation
import SwiftData
import TimelineEngine

/// Seule porte d'écriture du store (plan, principes d'architecture) : pose `updatedAt` et
/// `needsSync`, supprime par tombstone, garde les séquences de jour normalisées.
/// Les vues lisent avec `@Query` mais n'écrivent jamais directement.
@MainActor
public struct TaskStore {
    public enum StoreError: Error, Equatable {
        case emptyTitle
        case durationTooShort
    }

    public let context: ModelContext
    public var settings: AppSettings
    private let calendar: Calendar
    private let now: () -> Date

    public init(context: ModelContext, settings: AppSettings = .load(),
                calendar: Calendar = .current, now: @escaping () -> Date = Date.init) {
        self.context = context
        self.settings = settings
        self.calendar = calendar
        self.now = now
    }

    public var today: DayKey { DayKeys.key(for: now(), calendar: calendar) }
    public var tomorrow: DayKey { DayKeys.adding(1, to: today, calendar: calendar) ?? today }
    public var endOfThisWeek: DayKey { DayKeys.endOfWeek(containing: today, calendar: calendar) ?? today }

    // MARK: Capture et édition

    /// Crée une tâche en boîte de réception.
    @discardableResult
    public func capture(_ title: String, source: TaskSource) throws -> TaskItem {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw StoreError.emptyTitle }
        let task = TaskItem(title: trimmed, source: source, now: now())
        context.insert(task)
        try save()
        return task
    }

    public func setTitle(_ title: String, of task: TaskItem) throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw StoreError.emptyTitle }
        guard trimmed != task.title else { return }
        task.title = trimmed
        try commit(task)
    }

    public func setNotes(_ notes: String?, of task: TaskItem) throws {
        let cleaned = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = (cleaned?.isEmpty ?? true) ? nil : cleaned
        guard value != task.notes else { return }
        task.notes = value
        try commit(task)
    }

    public func setCategory(_ category: TaskCategory?, of task: TaskItem) throws {
        guard category?.rawValue != task.categoryRaw else { return }
        task.categoryRaw = category?.rawValue
        try commit(task)
    }

    public func setImportance(_ importance: Importance?, of task: TaskItem) throws {
        guard importance?.rawValue != task.importanceRaw else { return }
        task.importanceRaw = importance?.rawValue
        try commit(task)
    }

    public func setDueDate(_ day: DayKey?, of task: TaskItem) throws {
        guard day != task.dueDate else { return }
        task.dueDate = day
        try commit(task)
    }

    /// Minimum 5 min (cahier). `nil` rend la main à la durée par défaut de la catégorie.
    public func setDuration(_ minutes: Minutes?, of task: TaskItem) throws {
        if let minutes, minutes < Durations.minimum { throw StoreError.durationTooShort }
        guard minutes != task.durationMin else { return }
        task.durationMin = minutes
        if let day = task.scheduledDate {
            try normalizeDay(day)
        }
        try commit(task)
    }

    // MARK: Planification

    /// Pose la tâche en fin de séquence du jour, avec sa durée par défaut si elle n'en a pas.
    /// Une ancre garde son heure et prend sa place parmi les ancres (ADR-005).
    public func schedule(_ task: TaskItem, on day: DayKey) throws {
        let others = try tasks(on: day).filter { $0.id != task.id }
        let duration = Durations.defaultDuration(existing: task.durationMin, category: task.category,
                                                 defaults: settings.durations)
        let anchorStart = task.isAnchored ? task.anchorTime : nil
        let item = TimelineItem(id: task.id, orderIndex: 0, durationMin: duration, anchorStart: anchorStart)
        let changes = Sequencing.append(item, to: others.compactMap(\.timelineItem),
                                        dayStart: settings.dayStart)

        let previousDay = task.scheduledDate
        task.statusRaw = TaskStatus.scheduled.rawValue
        task.scheduledDate = day
        task.durationMin = duration
        task.orderIndex = changes[task.id] ?? task.orderIndex
        apply(changes, to: others)
        touch(task)
        if let previousDay, previousDay != day {
            try normalizeDay(previousDay)
        }
        try save()
    }

    /// Remet la tâche en boîte de réception. La durée est gardée comme suggestion.
    public func unschedule(_ task: TaskItem) throws {
        let previousDay = task.scheduledDate
        task.statusRaw = TaskStatus.inbox.rawValue
        task.scheduledDate = nil
        task.orderIndex = nil
        task.isAnchored = false
        task.anchorTime = nil
        task.completedAt = nil
        touch(task)
        if let previousDay {
            try normalizeDay(previousDay)
        }
        try save()
    }

    /// Suppression par tombstone : la ligne reste pour que la synchro propage la suppression.
    public func delete(_ task: TaskItem) throws {
        guard task.deletedAt == nil else { return }
        let previousDay = task.scheduledDate
        task.deletedAt = now()
        touch(task)
        if let previousDay {
            try normalizeDay(previousDay)
        }
        try save()
    }

    // MARK: Requêtes (toujours sans les tombstones)

    public func inbox() throws -> [TaskItem] {
        try context.fetch(TaskItem.inboxDescriptor)
    }

    /// Tâches posées sur un jour, faites comprises, dans l'ordre stocké.
    public func tasks(on day: DayKey) throws -> [TaskItem] {
        let target: String? = day
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.deletedAt == nil && $0.scheduledDate == target },
            sortBy: [SortDescriptor(\.orderIndex)])
        return try context.fetch(descriptor).filter { $0.status == .scheduled || $0.status == .done }
    }

    /// Tâches posées entre deux jours inclus (vue semaine).
    public func tasks(from start: DayKey, through end: DayKey) throws -> [TaskItem] {
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.deletedAt == nil && $0.scheduledDate != nil })
        return try context.fetch(descriptor).filter { task in
            guard let day = task.scheduledDate else { return false }
            return day >= start && day <= end && (task.status == .scheduled || task.status == .done)
        }
    }

    // MARK: Interne

    /// Réaligne la séquence stockée sur la séquence affichée (ADR-005).
    private func normalizeDay(_ day: DayKey) throws {
        let dayTasks = try tasks(on: day)
        let changes = Sequencing.normalize(items: dayTasks.compactMap(\.timelineItem),
                                           dayStart: settings.dayStart)
        apply(changes, to: dayTasks)
    }

    private func apply(_ changes: [UUID: Int], to tasks: [TaskItem]) {
        for task in tasks {
            guard let index = changes[task.id], index != task.orderIndex else { continue }
            task.orderIndex = index
            touch(task)
        }
    }

    private func touch(_ task: TaskItem) {
        task.updatedAt = now()
        task.needsSync = true
    }

    private func commit(_ task: TaskItem) throws {
        touch(task)
        try save()
    }

    private func save() throws {
        if context.hasChanges {
            try context.save()
        }
    }
}
