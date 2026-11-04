import Foundation
import SwiftData
import TimelineEngine

/// Sections de la boîte de réception (ADR-014).
extension TaskStore {
    public static let sectionsSeededKey = "sections.seeded"

    /// Crée les sections fournies au premier lancement, une seule fois.
    public func ensureDefaultSections(defaults: UserDefaults = AppGroup.defaults) throws {
        guard !defaults.bool(forKey: Self.sectionsSeededKey) else { return }
        if try sections().isEmpty {
            for (index, preset) in SectionPreset.all.enumerated() {
                context.insert(TaskSection(
                    name: preset.name, symbol: preset.symbol, sortIndex: index * OrderIndex.step,
                    defaultDuration: preset.defaultDuration, isPlannable: preset.isPlannable,
                    keepsMemory: preset.keepsMemory, repeatRule: preset.repeatRule, kind: preset.kind,
                    template: preset.template, now: now()))
            }
            try save()
        }
        defaults.set(true, forKey: Self.sectionsSeededKey)
    }

    public func sections() throws -> [TaskSection] {
        try context.fetch(TaskSection.orderedDescriptor)
    }

    public func section(of task: TaskItem) throws -> TaskSection? {
        guard let id = task.sectionId else { return nil }
        var descriptor = FetchDescriptor<TaskSection>(predicate: #Predicate { $0.id == id && $0.deletedAt == nil })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Crée une section. Hors du type « À faire », les règles suivent le type (ADR-015) : pas de
    /// journée ni de répétition, et la mémoire pour le seul type `memory`. Un modèle (ADR-016)
    /// décide du type.
    @discardableResult
    public func createSection(name: String, symbol: String = "folder", defaultDuration: Minutes? = nil,
                              isPlannable: Bool = true, keepsMemory: Bool = false,
                              repeatRule: SectionRepeat = .none, kind: SectionKind = .tasks,
                              template: SectionTemplate? = nil) throws -> TaskSection {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw StoreError.emptyTitle }
        let kind = template?.kind ?? kind
        let rules = Self.rules(kind: kind, isPlannable: isPlannable, keepsMemory: keepsMemory, repeatRule: repeatRule)
        let last = try sections().map(\.sortIndex).max()
        let section = TaskSection(
            name: trimmed, symbol: symbol, sortIndex: (last ?? 0) + OrderIndex.step,
            defaultDuration: defaultDuration, isPlannable: rules.isPlannable, keepsMemory: rules.keepsMemory,
            repeatRule: rules.repeatRule, kind: kind, template: kind.isMemorySpace ? template : nil, now: now())
        context.insert(section)
        try save()
        return section
    }

    /// Modifie une section. Changer ses règles ne déplace pas les tâches existantes, sauf une section
    /// qui ne se pose plus dans la journée : ses tâches non faites retournent dans la section.
    /// `kind` à `nil` garde le type actuel ; un modèle décide du type.
    public func updateSection(_ section: TaskSection, name: String, symbol: String,
                              defaultDuration: Minutes?, isPlannable: Bool, keepsMemory: Bool,
                              repeatRule: SectionRepeat, kind: SectionKind? = nil,
                              template: SectionTemplate? = nil) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw StoreError.emptyTitle }
        if let defaultDuration, defaultDuration < Durations.minimum { throw StoreError.durationTooShort }
        let kind = template?.kind ?? kind ?? section.kind
        let rules = Self.rules(kind: kind, isPlannable: isPlannable, keepsMemory: keepsMemory, repeatRule: repeatRule)
        let wasDayPlannable = section.isDayPlannable
        let kindChanged = kind != section.kind
        section.name = trimmed
        section.symbol = symbol
        section.defaultDuration = defaultDuration
        section.isPlannable = rules.isPlannable
        section.keepsMemory = rules.keepsMemory
        section.repeatRaw = rules.repeatRule.rawValue
        section.kindRaw = kind.rawValue
        if !kind.isMemorySpace {
            section.templateRaw = nil
        } else if let template {
            section.templateRaw = template.rawValue
        }
        touch(section)
        // Les entrées suivent l'espace de leur section.
        let space = kind.isMemorySpace ? TaskSpace.memory.rawValue : nil
        for task in try tasks(in: section) + memory(of: section) where task.spaceRaw != space {
            task.spaceRaw = space
            touch(task)
        }
        if wasDayPlannable && !section.isDayPlannable && (kindChanged || !rules.isPlannable) {
            for task in try tasks(in: section) where task.scheduledDate != nil && !task.isDone {
                try unschedule(task)
            }
        }
        try save()
    }

    /// Règles imposées par le type d'une section.
    static func rules(kind: SectionKind, isPlannable: Bool, keepsMemory: Bool,
                      repeatRule: SectionRepeat) -> (isPlannable: Bool, keepsMemory: Bool, repeatRule: SectionRepeat) {
        switch kind {
        case .tasks: (isPlannable, keepsMemory, repeatRule)
        case .memory: (false, true, .none)
        case .checklist, .periods: (false, false, .none)
        }
    }

    /// Vide les articles cochés d'une liste (courses) : suppression par tombstone.
    /// - Returns: le nombre d'articles retirés.
    @discardableResult
    public func clearChecked(in section: TaskSection) throws -> Int {
        let checked = try memory(of: section)
        guard !checked.isEmpty else { return 0 }
        let stamp = now()
        for item in checked {
            item.deletedAt = stamp
            touch(item)
        }
        try save()
        return checked.count
    }

    /// Supprime une section ; ses tâches retournent dans « À trier » de son espace, rien n'est perdu.
    public func deleteSection(_ section: TaskSection) throws {
        guard section.deletedAt == nil else { return }
        let space = section.kind.isMemorySpace ? TaskSpace.memory.rawValue : nil
        for task in try tasks(in: section) + memory(of: section) {
            task.sectionId = nil
            task.spaceRaw = space
            touch(task)
        }
        section.deletedAt = now()
        touch(section)
        try save()
    }

    /// Déplace une section à une position de la liste.
    public func moveSection(_ section: TaskSection, to position: Int) throws {
        var ordered = try sections().map(\.id)
        ordered.removeAll { $0 == section.id }
        ordered.insert(section.id, at: min(max(position, 0), ordered.count))
        let all = try sections()
        let current = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0.sortIndex) })
        let changes = OrderIndex.reindex(target: ordered, current: current)
        for item in all {
            guard let index = changes[item.id], index != item.sortIndex else { continue }
            item.sortIndex = index
            touch(item)
        }
        try save()
    }

    /// À faire dans une section : en boîte, ou posées sur un jour et pas encore faites.
    public func tasks(in section: TaskSection?) throws -> [TaskItem] {
        let id = section?.id
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.deletedAt == nil && $0.sectionId == id },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return try context.fetch(descriptor).filter { $0.status == .inbox || $0.status == .scheduled }
    }

    /// Mémoire d'une section : éléments terminés, le plus récent en tête.
    public func memory(of section: TaskSection) throws -> [TaskItem] {
        let id: UUID? = section.id
        let done = TaskStatus.done.rawValue
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.deletedAt == nil && $0.sectionId == id && $0.statusRaw == done },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)])
        return try context.fetch(descriptor)
    }

    func touch(_ section: TaskSection) {
        section.updatedAt = now()
        section.needsSync = true
    }
}
