import CoreModels
import SwiftUI
import TimelineEngine

/// Demande d'ouverture du sélecteur de jour.
struct DayPickerRequest: Identifiable {
    enum Kind { case schedule, due }

    let kind: Kind
    let task: TaskItem

    var id: String { "\(kind)-\(task.id)" }
    var title: String { kind == .schedule ? "Planifier le…" : "Échéance" }
}

/// Section d'une tâche parmi une liste déjà chargée.
extension Array where Element == TaskSection {
    func section(of task: TaskItem) -> TaskSection? {
        guard let id = task.sectionId else { return nil }
        return first { $0.id == id }
    }
}

/// Gestes rapides sur une tâche (menu contextuel), partagés entre la boîte et les sections.
struct TaskActionsMenu: View {
    let task: TaskItem
    let store: TaskStore
    let sections: [TaskSection]
    let pickDay: (DayPickerRequest) -> Void
    /// Terminer : avis pour une section mémoire, simple coche sinon.
    let finish: (TaskItem) -> Void
    let run: (() throws -> Void) -> Void

    var body: some View {
        let section = sections.section(of: task)

        Button("Terminer", systemImage: "checkmark.circle") { finish(task) }

        if section?.isPlannable ?? true {
            Menu {
                Button("Aujourd'hui", systemImage: "sun.max") { run { try store.schedule(task, on: store.today) } }
                Button("Demain", systemImage: "sunrise") { run { try store.schedule(task, on: store.tomorrow) } }
                Button("Planifier le…", systemImage: "calendar") { pickDay(DayPickerRequest(kind: .schedule, task: task)) }
            } label: {
                Label("Planifier", systemImage: "calendar.badge.plus")
            }
        }

        Menu {
            Picker("Section", selection: Binding(
                get: { task.sectionId },
                set: { id in run { try store.setSection(sections.first { $0.id == id }, of: task) } }
            )) {
                Text("À trier").tag(UUID?.none)
                ForEach(sections) { Label($0.name, systemImage: $0.symbol).tag(Optional($0.id)) }
            }
        } label: {
            Label("Ranger dans…", systemImage: "folder")
        }

        Menu {
            Picker("Étiquette", selection: Binding(
                get: { task.tag },
                set: { value in run { try store.setTag(value, of: task) } }
            )) {
                Text("Aucune").tag(TaskTag?.none)
                ForEach(TaskTag.allCases, id: \.self) { Label($0.label, systemImage: $0.symbol).tag(Optional($0)) }
            }
        } label: {
            Label("Étiquette", systemImage: "tag")
        }

        Menu {
            Button("Aujourd'hui") { run { try store.setDueDate(store.today, of: task) } }
            Button("Demain") { run { try store.setDueDate(store.tomorrow, of: task) } }
            Button("Cette semaine") { run { try store.setDueDate(store.endOfThisWeek, of: task) } }
            Button("Choisir…") { pickDay(DayPickerRequest(kind: .due, task: task)) }
            if task.dueDate != nil {
                Button("Retirer l'échéance", systemImage: "xmark") { run { try store.setDueDate(nil, of: task) } }
            }
        } label: {
            Label("Échéance", systemImage: "flag")
        }

        Divider()

        Button("Supprimer", systemImage: "trash", role: .destructive) { run { try store.delete(task) } }
    }
}
