import CoreModels
import SwiftData
import SwiftUI
import TimelineEngine

/// Une section : ce qui reste à faire, et sa mémoire si elle en garde une (ADR-014).
struct SectionView: View {
    let section: TaskSection

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var items: [TaskItem]
    @Query(TaskSection.orderedDescriptor) private var sections: [TaskSection]
    @FocusState private var captureFocused: Bool
    @State private var showMemory = false
    @State private var dayPicker: DayPickerRequest?
    @State private var reviewing: TaskItem?
    @State private var editing: SectionEditing?
    @State private var errorMessage: String?
    @State private var doneCount = 0

    init(section: TaskSection) {
        self.section = section
        let id: UUID? = section.id
        _items = Query(filter: #Predicate<TaskItem> { $0.deletedAt == nil && $0.sectionId == id },
                       sort: [SortDescriptor(\.createdAt, order: .reverse)])
    }

    private var store: TaskStore { TaskStore(context: context) }

    var body: some View {
        let today = store.today
        let todo = items
            .filter { $0.status == .inbox || $0.status == .scheduled }
            .sorted { ($0.tag?.rank ?? TaskTag.allCases.count) < ($1.tag?.rank ?? TaskTag.allCases.count) }
        let memory = items
            .filter { $0.status == .done }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }

        List {
            if section.keepsMemory {
                Picker("Affichage", selection: $showMemory) {
                    Text("À faire").tag(false)
                    Text("Mémoire · \(memory.count)").tag(true)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            if showMemory {
                ForEach(memory) { task in
                    NavigationLink(value: task) {
                        MemoryRow(task: task, today: today)
                    }
                    .swipeActions {
                        Button("Remettre à faire", systemImage: "arrow.uturn.backward") {
                            run { try store.toggleDone(task) }
                        }
                    }
                }
                if memory.isEmpty {
                    Text("Rien encore. Ce que tu termines ici est gardé avec ton avis.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    CaptureField(focus: $captureFocused) { title in
                        run {
                            let task = try store.capture(title, source: .manual)
                            try store.setSection(section, of: task)
                        }
                    }
                }
                Section {
                    ForEach(todo) { task in
                        row(task, today: today)
                    }
                    if todo.isEmpty {
                        Text("Rien à faire ici pour l'instant.")
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text(footer)
                }
            }
        }
        .navigationTitle(section.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Modifier", systemImage: "slider.horizontal.3") { editing = SectionEditing(section: section) }
            }
        }
        .sheet(item: $dayPicker) { request in
            DayPickerSheet(title: request.title, initial: request.task.dueDate ?? store.today) { day in
                switch request.kind {
                case .schedule: run { try store.schedule(request.task, on: day) }
                case .due: run { try store.setDueDate(day, of: request.task) }
                }
            }
        }
        .sheet(item: $reviewing) { task in
            ReviewSheet(task: task) { review, note in
                run { try store.complete(task, review: review, note: note) }
                doneCount += 1
            }
        }
        .sheet(item: $editing, onDismiss: {
            if section.deletedAt != nil { dismiss() }
        }) { editing in
            SectionEditor(section: editing.section)
        }
        .alert("Action impossible", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .sensoryFeedback(.success, trigger: doneCount)
    }

    private var footer: String {
        switch (section.isPlannable, section.repeatRule) {
        case (false, _): "Ces tâches ne se posent pas dans la journée."
        case (true, .daily): "Posées seules dans ta journée chaque matin."
        case (true, .permanent): "Toujours disponibles : cochées, elles restent ici avec la date de la dernière fois."
        case (true, .none): "Glisse vers la gauche pour planifier."
        }
    }

    private func row(_ task: TaskItem, today: DayKey) -> some View {
        NavigationLink(value: task) {
            TaskRow(task: task, today: today)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button(section.keepsMemory ? "C'est fait…" : "Fait", systemImage: "checkmark") { finish(task) }
                .tint(.green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if section.isPlannable && task.scheduledDate == nil {
                Button("Aujourd'hui", systemImage: "sun.max") { run { try store.schedule(task, on: store.today) } }
                    .tint(.accentColor)
                Button("Planifier le…", systemImage: "calendar") {
                    dayPicker = DayPickerRequest(kind: .schedule, task: task)
                }
                .tint(.teal)
            }
        }
        .contextMenu {
            TaskActionsMenu(task: task, store: store, sections: sections, pickDay: { dayPicker = $0 },
                            finish: finish, run: run)
        }
    }

    private func finish(_ task: TaskItem) {
        if section.keepsMemory {
            reviewing = task
        } else {
            run { try store.toggleDone(task) }
            doneCount += 1
        }
    }

    private func run(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
