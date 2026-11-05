import Foundation

/// Sous-tâches et champs du modèle de section (ADR-016). Rangés dans la tâche en JSON : ils
/// voyagent avec elle à la synchro, sous la même règle « dernière écriture gagnante ».
extension TaskStore {
    // MARK: Sous-tâches

    @discardableResult
    public func addSubtask(_ title: String, category: String? = nil, to task: TaskItem) throws -> Subtask {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw StoreError.emptyTitle }
        let subtask = Subtask(title: trimmed, category: category)
        try setSubtasks(task.subtasks + [subtask], of: task)
        return subtask
    }

    /// Cocher une sous-tâche ne touche pas à la tâche : on la termine soi-même.
    public func toggleSubtask(_ id: UUID, of task: TaskItem) throws {
        var subtasks = task.subtasks
        guard let index = subtasks.firstIndex(where: { $0.id == id }) else { return }
        subtasks[index].isDone.toggle()
        try setSubtasks(subtasks, of: task)
    }

    public func renameSubtask(_ id: UUID, to title: String, of task: TaskItem) throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw StoreError.emptyTitle }
        var subtasks = task.subtasks
        guard let index = subtasks.firstIndex(where: { $0.id == id }), subtasks[index].title != trimmed else { return }
        subtasks[index].title = trimmed
        try setSubtasks(subtasks, of: task)
    }

    public func deleteSubtask(_ id: UUID, of task: TaskItem) throws {
        let subtasks = task.subtasks
        guard subtasks.contains(where: { $0.id == id }) else { return }
        try setSubtasks(subtasks.filter { $0.id != id }, of: task)
    }

    /// Déplace une sous-tâche à une position de la liste.
    public func moveSubtask(_ id: UUID, to position: Int, of task: TaskItem) throws {
        var subtasks = task.subtasks
        guard let index = subtasks.firstIndex(where: { $0.id == id }) else { return }
        let moved = subtasks.remove(at: index)
        subtasks.insert(moved, at: min(max(position, 0), subtasks.count))
        try setSubtasks(subtasks, of: task)
    }

    private func setSubtasks(_ subtasks: [Subtask], of task: TaskItem) throws {
        let raw = Self.encode(subtasks)
        guard raw != task.subtasksRaw else { return }
        task.subtasksRaw = raw
        try commit(task)
    }

    // MARK: Champs du modèle

    /// Une valeur vide retire le champ.
    public func setField(_ key: String, to value: String?, of task: TaskItem) throws {
        var fields = task.fields
        let cleaned = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        fields[key] = (cleaned?.isEmpty ?? true) ? nil : cleaned
        let raw = Self.encode(fields: fields)
        guard raw != task.fieldsRaw else { return }
        task.fieldsRaw = raw
        try commit(task)
    }

    // MARK: Encodage

    /// `nil` pour une liste vide : la tâche n'est pas découpée.
    static func encode(_ subtasks: [Subtask]) -> String? {
        guard !subtasks.isEmpty, let data = try? JSONEncoder().encode(subtasks) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Clés triées : le même contenu donne toujours la même chaîne. Valeurs vides retirées.
    static func encode(fields: [String: String]) -> String? {
        let kept = fields.compactMapValues { value -> String? in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        guard !kept.isEmpty else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(kept) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
