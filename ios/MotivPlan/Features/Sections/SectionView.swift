import CoreModels
import SwiftData
import SwiftUI
import TimelineEngine

/// Une section : ce qui reste à faire, et sa mémoire si elle en garde une (ADR-014).
/// Pas de maquette dédiée : mêmes briques que la boîte de réception.
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

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScreenHeader(title: section.name, subtitle: rulesSummary.isEmpty ? nil : rulesSummary)
                    .padding(.horizontal, -16)

                if section.keepsMemory {
                    modePicker(memoryCount: memory.count)
                }

                if showMemory {
                    VStack(spacing: 6) {
                        ForEach(memory) { task in
                            NavigationLink(value: task) {
                                MemoryRow(task: task, today: today)
                                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Remettre à faire", systemImage: "arrow.uturn.backward") {
                                    run { try store.toggleDone(task) }
                                }
                            }
                        }
                        if memory.isEmpty {
                            emptyText("Rien encore. Ce que tu termines ici est gardé avec ton avis.")
                        }
                    }
                } else {
                    CaptureField(focus: $captureFocused, identifier: "section-capture-field") { title in
                        run {
                            let task = try store.capture(title, source: .manual)
                            try store.setSection(section, of: task)
                        }
                    }
                    VStack(spacing: 6) {
                        ForEach(todo) { task in
                            row(task, today: today)
                        }
                        if todo.isEmpty {
                            emptyText("Rien à faire ici pour l'instant.")
                        }
                    }
                    Text(footer)
                        .font(.meta)
                        .foregroundStyle(Palette.textTertiary)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Palette.background, for: .navigationBar)
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

    /// Sélecteur « À faire | Mémoire · 12 », comme le Semaine | Mois des maquettes.
    private func modePicker(memoryCount: Int) -> some View {
        HStack(spacing: 2) {
            modeButton("À faire", selected: !showMemory) { showMemory = false }
            modeButton("Mémoire · \(memoryCount)", selected: showMemory) { showMemory = true }
        }
        .padding(4)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func modeButton(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { action() }
        } label: {
            Text(label)
                .font(.manrope(13, selected ? .extrabold : .bold, relativeTo: .footnote))
                .foregroundStyle(selected ? Palette.onAccent : Palette.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(selected ? Palette.text : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(.subtitle)
            .foregroundStyle(Palette.textTertiary)
            .multilineTextAlignment(.center)
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 56)
            .overlay {
                RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                    .strokeBorder(Palette.border, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
    }

    /// « Chaque jour · 15 min », « Hors planning · Mémoire »…
    private var rulesSummary: String {
        var parts: [String] = []
        if section.isPlannable {
            if section.repeatRule != .none { parts.append(section.repeatRule.label) }
            if let minutes = section.defaultDuration { parts.append(TimeText.duration(minutes)) }
        } else {
            parts.append("Hors planning")
        }
        if section.keepsMemory { parts.append("Mémoire") }
        return parts.joined(separator: " · ")
    }

    private var footer: String {
        switch (section.isPlannable, section.repeatRule) {
        case (false, _): "Ces tâches ne se posent pas dans la journée."
        case (true, .daily): "Posées seules dans ta journée chaque matin."
        case (true, .permanent): "Toujours disponibles : cochées, elles restent ici avec la date de la dernière fois."
        case (true, .none): "Appui long sur une tâche pour la planifier."
        }
    }

    private func row(_ task: TaskItem, today: DayKey) -> some View {
        HStack(spacing: 0) {
            NavigationLink(value: task) {
                TaskRow(task: task, today: today)
            }
            .buttonStyle(.plain)
            Button {
                finish(task)
            } label: {
                Circle()
                    .strokeBorder(Palette.ring, lineWidth: 2)
                    .frame(width: 26, height: 26)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(section.keepsMemory ? "C'est fait…" : "Fait")
            .padding(.trailing, 6)
        }
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
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
