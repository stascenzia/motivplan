import CoreModels
import SwiftData
import SwiftUI
import TimelineEngine

/// Détail d'une tâche. Seul endroit où le nombre de reports est visible (principe 2).
struct TaskDetailView: View {
    let task: TaskItem

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var notes = ""
    @State private var dayPicker: DayPickerRequest?
    @State private var confirmDelete = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field { case title, notes }

    private var store: TaskStore { TaskStore(context: context) }

    var body: some View {
        let today = store.today
        Form {
            Section {
                TextField("Titre", text: $title, axis: .vertical)
                    .font(.headline)
                    .focused($focusedField, equals: .title)
                    .onSubmit(commitText)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...10)
                    .focused($focusedField, equals: .notes)
            }

            Section("Planification") {
                if let day = task.scheduledDate {
                    LabeledContent("Prévue", value: DayLabel.text(for: day, today: today))
                    Button("Remettre dans la boîte", systemImage: "tray.and.arrow.down") {
                        run { try store.unschedule(task) }
                    }
                } else {
                    Button("Aujourd'hui", systemImage: "sun.max") { run { try store.schedule(task, on: store.today) } }
                    Button("Demain", systemImage: "sunrise") { run { try store.schedule(task, on: store.tomorrow) } }
                    Button("Planifier le…", systemImage: "calendar") {
                        dayPicker = DayPickerRequest(kind: .schedule, task: task)
                    }
                }
            }

            Section("Détails") {
                Picker("Catégorie", selection: Binding(
                    get: { task.category },
                    set: { value in run { try store.setCategory(value, of: task) } }
                )) {
                    Text("Aucune").tag(TaskCategory?.none)
                    ForEach(TaskCategory.allCases, id: \.self) { Text($0.label).tag(Optional($0)) }
                }

                Picker("Importance", selection: Binding(
                    get: { task.importance },
                    set: { value in run { try store.setImportance(value, of: task) } }
                )) {
                    Text("Non précisée").tag(Importance?.none)
                    ForEach(Importance.allCases, id: \.self) { Text($0.label).tag(Optional($0)) }
                }

                Button {
                    dayPicker = DayPickerRequest(kind: .due, task: task)
                } label: {
                    LabeledContent("Échéance") {
                        if let due = task.dueDate {
                            Text(DayLabel.text(for: due, today: today))
                                .foregroundStyle(task.isOverdue(today: today) ? Color.gentleWarning : .secondary)
                        } else {
                            Text("Aucune").foregroundStyle(.secondary)
                        }
                    }
                }
                .foregroundStyle(.primary)
                if task.dueDate != nil {
                    Button("Retirer l'échéance") { run { try store.setDueDate(nil, of: task) } }
                }

                if task.postponeCount > 0 {
                    LabeledContent("Reportée", value: task.postponeCount == 1 ? "1 fois" : "\(task.postponeCount) fois")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button("Supprimer la tâche", role: .destructive) { confirmDelete = true }
            }
        }
        .navigationTitle("Tâche")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if focusedField != nil {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { focusedField = nil }
                }
            }
        }
        .onAppear {
            title = task.title
            notes = task.notes ?? ""
        }
        .onChange(of: focusedField) { previous, current in
            if previous != nil, current != previous { commitText() }
        }
        .onDisappear(perform: commitText)
        .sheet(item: $dayPicker) { request in
            DayPickerSheet(title: request.title, initial: task.dueDate ?? store.today) { day in
                switch request.kind {
                case .schedule: run { try store.schedule(task, on: day) }
                case .due: run { try store.setDueDate(day, of: task) }
                }
            }
        }
        .confirmationDialog("Supprimer « \(task.title) » ?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) {
                run { try store.delete(task) }
                dismiss()
            }
        }
        .alert("Action impossible", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    /// Titre et notes s'enregistrent en quittant le champ. Un titre vidé reprend l'ancien.
    private func commitText() {
        guard task.deletedAt == nil else { return }
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            title = task.title
        } else {
            run { try store.setTitle(title, of: task) }
        }
        run { try store.setNotes(notes, of: task) }
    }

    private func run(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
