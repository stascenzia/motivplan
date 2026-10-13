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

/// Gestes rapides sur une tâche (menu contextuel), partagés entre la boîte et le détail.
struct TaskActionsMenu: View {
    let task: TaskItem
    let store: TaskStore
    let pickDay: (DayPickerRequest) -> Void
    let run: (() throws -> Void) -> Void

    var body: some View {
        Menu {
            Button("Aujourd'hui", systemImage: "sun.max") { run { try store.schedule(task, on: store.today) } }
            Button("Demain", systemImage: "sunrise") { run { try store.schedule(task, on: store.tomorrow) } }
            Button("Planifier le…", systemImage: "calendar") { pickDay(DayPickerRequest(kind: .schedule, task: task)) }
        } label: {
            Label("Planifier", systemImage: "calendar.badge.plus")
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

        Menu {
            Picker("Catégorie", selection: Binding(
                get: { task.category },
                set: { value in run { try store.setCategory(value, of: task) } }
            )) {
                Text("Aucune").tag(TaskCategory?.none)
                ForEach(TaskCategory.allCases, id: \.self) { Text($0.label).tag(Optional($0)) }
            }
        } label: {
            Label("Catégorie", systemImage: "tag")
        }

        Menu {
            Picker("Importance", selection: Binding(
                get: { task.importance },
                set: { value in run { try store.setImportance(value, of: task) } }
            )) {
                Text("Non précisée").tag(Importance?.none)
                ForEach(Importance.allCases, id: \.self) { Text($0.label).tag(Optional($0)) }
            }
        } label: {
            Label("Importance", systemImage: "exclamationmark.circle")
        }

        Divider()

        Button("Supprimer", systemImage: "trash", role: .destructive) { run { try store.delete(task) } }
    }
}
