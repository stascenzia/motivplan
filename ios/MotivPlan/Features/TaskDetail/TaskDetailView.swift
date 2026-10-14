import CoreModels
import SwiftData
import SwiftUI
import TimelineEngine

/// Détail d'une tâche. Seul endroit où le nombre de reports est visible (principe 2).
struct TaskDetailView: View {
    let task: TaskItem

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(TaskSection.orderedDescriptor) private var sections: [TaskSection]
    @State private var reviewing = false
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

            if task.scheduledDate != nil {
                timingSection
            }

            if sections.section(of: task)?.keepsMemory == true {
                memorySection
            }

            Section("Détails") {
                Picker("Section", selection: Binding(
                    get: { task.sectionId },
                    set: { id in run { try store.setSection(sections.first { $0.id == id }, of: task) } }
                )) {
                    Text("À trier").tag(UUID?.none)
                    ForEach(sections) { Text($0.name).tag(Optional($0.id)) }
                }

                Picker("Étiquette", selection: Binding(
                    get: { task.tag },
                    set: { value in run { try store.setTag(value, of: task) } }
                )) {
                    Text("Aucune").tag(TaskTag?.none)
                    ForEach(TaskTag.allCases, id: \.self) { Text($0.label).tag(Optional($0)) }
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

    /// Mémoire : avis et commentaire, ou terminer avec un avis (ADR-014).
    private var memorySection: some View {
        Section("Mémoire") {
            if task.isDone {
                LabeledContent("Avis", value: task.review?.label ?? "Aucun")
                if let note = task.reviewNote {
                    Text(note).foregroundStyle(.secondary)
                }
                if let done = task.completedAt {
                    LabeledContent("Terminé", value: done.formatted(date: .abbreviated, time: .omitted))
                }
                Button("Modifier l'avis", systemImage: "hand.thumbsup") { reviewing = true }
                Button("Remettre à faire", systemImage: "arrow.uturn.backward") { run { try store.toggleDone(task) } }
            } else {
                Button("C'est fait…", systemImage: "checkmark.circle") { reviewing = true }
            }
        }
        .sheet(isPresented: $reviewing) {
            ReviewSheet(task: task) { review, note in run { try store.complete(task, review: review, note: note) } }
        }
    }

    /// Durée, heure fixe, position : réglages par boutons, sans sélecteur d'heure (principe 4).
    private var timingSection: some View {
        let duration = task.durationMin ?? Durations.fallback
        return Section("Dans la journée") {
            HStack {
                LabeledContent("Durée", value: TimeText.duration(duration))
                stepButton("−15") { try store.setDuration(max(duration - 15, Durations.minimum), of: task) }
                    .disabled(duration <= Durations.minimum)
                stepButton("+15") { try store.setDuration(duration + 15, of: task) }
            }

            Toggle("Heure fixe", isOn: Binding(
                get: { task.isAnchored },
                set: { on in run { try store.setAnchor(on ? TimeText.nextRoundHour() : nil, of: task) } }
            ))

            if task.isAnchored, let start = task.anchorTime {
                HStack(spacing: 6) {
                    Text(TimeText.clock(start))
                        .font(.title3.monospacedDigit().weight(.semibold))
                    Spacer()
                    stepButton("−1 h") { try store.setAnchor(start - 60, of: task) }
                    stepButton("−15") { try store.setAnchor(start - 15, of: task) }
                    stepButton("+15") { try store.setAnchor(start + 15, of: task) }
                    stepButton("+1 h") { try store.setAnchor(start + 60, of: task) }
                }
            } else {
                // Repli sans glisser pour réordonner (ADR-008).
                HStack {
                    Text("Position")
                    Spacer()
                    stepButton("Monter", systemImage: "arrow.up") { try store.move(task, by: -1) }
                    stepButton("Descendre", systemImage: "arrow.down") { try store.move(task, by: 1) }
                }
            }
        }
    }

    private func stepButton(_ title: String, systemImage: String? = nil,
                            action: @escaping () throws -> Void) -> some View {
        Button {
            run(action)
        } label: {
            if let systemImage {
                Label(title, systemImage: systemImage).labelStyle(.iconOnly)
            } else {
                Text(title).monospacedDigit()
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
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
