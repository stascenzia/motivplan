import CoreModels
import SwiftData
import SwiftUI
import TimelineEngine

/// Détail d'une tâche (maquette « Détail d'une tâche ») : titre modifiable en grand, puis des
/// cartes empilées. Seul endroit où le nombre de reports est visible (principe 2).
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
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Titre", text: $title, axis: .vertical)
                    .font(.manrope(26, .extrabold, relativeTo: .title))
                    .tracking(-0.5)
                    .foregroundStyle(Palette.text)
                    .focused($focusedField, equals: .title)
                    .submitLabel(.done)
                    .onSubmit(commitText)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)

                planningCard(today: today)
                if task.scheduledDate != nil {
                    durationCard
                    anchorCard
                }
                if sections.section(of: task)?.keepsMemory == true {
                    memoryCard
                }
                sectionCard
                tagCard
                dueCard(today: today)
                notesCard
                footer
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .screenBackground()
        .navigationTitle("Tâche")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Palette.background, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if focusedField != nil {
                    Button("OK") { focusedField = nil }
                } else {
                    Text("Enregistré automatiquement")
                        .font(.meta)
                        .foregroundStyle(Palette.textTertiary)
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
        .sheet(isPresented: $reviewing) {
            ReviewSheet(task: task) { review, note in run { try store.complete(task, review: review, note: note) } }
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

    // MARK: Cartes

    private func cardTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.groupLabel)
            .tracking(0.7)
            .foregroundStyle(Palette.textTertiary)
            .accessibilityAddTraits(.isHeader)
    }

    private func planningCard(today: DayKey) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            cardTitle("Planification")
            if let day = task.scheduledDate {
                HStack {
                    Text("Prévue \(DayLabel.text(for: day, today: today).lowercased())")
                        .font(.rowTitle)
                        .foregroundStyle(Palette.text)
                    Spacer()
                    Button("Remettre dans la boîte") { run { try store.unschedule(task) } }
                        .buttonStyle(PillButtonStyle())
                }
            } else {
                FlowLayout(spacing: 6) {
                    Button("Aujourd'hui") { run { try store.schedule(task, on: store.today) } }
                        .buttonStyle(PillButtonStyle(prominent: true))
                    Button("Demain") { run { try store.schedule(task, on: store.tomorrow) } }
                        .buttonStyle(PillButtonStyle())
                    Button("Planifier le…") { dayPicker = DayPickerRequest(kind: .schedule, task: task) }
                        .buttonStyle(PillButtonStyle())
                }
            }
        }
        .card()
    }

    /// Durée par pas de 15 min, sans sélecteur (principe 4).
    private var durationCard: some View {
        let duration = task.durationMin ?? Durations.fallback
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                cardTitle("Durée")
                Text("Par pas de 15 min")
                    .font(.meta)
                    .foregroundStyle(Palette.textTertiary)
            }
            Spacer()
            StepButton(text: "−", label: "Moins 15 minutes") {
                run { try store.setDuration(max(duration - 15, Durations.minimum), of: task) }
            }
            .disabled(duration <= Durations.minimum)
            Text(TimeText.duration(duration))
                .font(.manrope(20, .extrabold, relativeTo: .title3).monospacedDigit())
                .foregroundStyle(Palette.text)
                .frame(minWidth: 76)
                .accessibilityLabel("Durée \(TimeText.duration(duration))")
            StepButton(text: "+", label: "Plus 15 minutes") {
                run { try store.setDuration(duration + 15, of: task) }
            }
        }
        .card()
    }

    /// Heure fixe : interrupteur, puis réglage par boutons. Sinon, monter ou descendre (ADR-008).
    private var anchorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "clock")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.text)
                    .frame(width: 34, height: 34)
                    .background(Palette.control, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Heure fixe")
                        .font(.rowTitle)
                        .foregroundStyle(Palette.text)
                    Text("Rendez-vous, cours, réunion")
                        .font(.meta)
                        .foregroundStyle(Palette.textTertiary)
                }
                Spacer()
                Toggle("Heure fixe", isOn: Binding(
                    get: { task.isAnchored },
                    set: { on in run { try store.setAnchor(on ? TimeText.nextRoundHour() : nil, of: task) } }
                ))
                .labelsHidden()
                .tint(Palette.accent)
            }
            if task.isAnchored, let start = task.anchorTime {
                HStack(spacing: 6) {
                    StepButton(text: "−1 h", label: "Moins une heure", width: 0) { run { try store.setAnchor(start - 60, of: task) } }
                    StepButton(text: "−15", label: "Moins 15 minutes", width: 0) { run { try store.setAnchor(start - 15, of: task) } }
                    Text(TimeText.clock(start))
                        .font(.manrope(22, .extrabold, relativeTo: .title2).monospacedDigit())
                        .foregroundStyle(Palette.text)
                        .frame(minWidth: 78)
                    StepButton(text: "+15", label: "Plus 15 minutes", width: 0) { run { try store.setAnchor(start + 15, of: task) } }
                    StepButton(text: "+1 h", label: "Plus une heure", width: 0) { run { try store.setAnchor(start + 60, of: task) } }
                }
                .frame(maxWidth: .infinity)
            } else {
                HStack(spacing: 6) {
                    Text("Position dans la journée")
                        .font(.manrope(13, .semibold, relativeTo: .footnote))
                        .foregroundStyle(Palette.textSecondary)
                    Spacer()
                    StepButton(text: "↑", label: "Monter") { run { try store.move(task, by: -1) } }
                    StepButton(text: "↓", label: "Descendre") { run { try store.move(task, by: 1) } }
                }
            }
        }
        .card()
    }

    /// Mémoire : avis et commentaire, ou terminer avec un avis (ADR-014).
    private var memoryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardTitle("Mémoire")
            if task.isDone {
                HStack(spacing: 8) {
                    Image(systemName: task.review?.symbol ?? "checkmark")
                    Text(task.review?.label ?? "Sans avis")
                    if let done = task.completedAt {
                        Text("· \(done.formatted(date: .abbreviated, time: .omitted))")
                            .foregroundStyle(Palette.textTertiary)
                    }
                }
                .font(.rowTitle)
                .foregroundStyle(Palette.text)
                if let note = task.reviewNote, !note.isEmpty {
                    Text(note)
                        .font(.manrope(14, .medium, relativeTo: .body))
                        .foregroundStyle(Palette.textSecondary)
                }
                FlowLayout(spacing: 6) {
                    Button("Modifier l'avis") { reviewing = true }
                        .buttonStyle(PillButtonStyle())
                    Button("Remettre à faire") { run { try store.toggleDone(task) } }
                        .buttonStyle(PillButtonStyle())
                }
            } else {
                Button("C'est fait…") { reviewing = true }
                    .buttonStyle(PillButtonStyle(prominent: true))
            }
        }
        .card()
    }

    private var sectionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardTitle("Section")
            FlowLayout(spacing: 6) {
                choice("À trier", symbol: "tray", selected: task.sectionId == nil) {
                    run { try store.setSection(nil, of: task) }
                }
                ForEach(sections) { section in
                    choice(section.name, symbol: section.symbol, selected: task.sectionId == section.id) {
                        run { try store.setSection(section, of: task) }
                    }
                }
            }
        }
        .card()
    }

    /// L'étiquette donne sa couleur à la tâche (décision du 2026-10-15).
    private var tagCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardTitle("Étiquette")
            FlowLayout(spacing: 6) {
                ForEach(TaskTag.allCases, id: \.self) { tag in
                    choice(tag.label, dot: TagColors.of(tag).vivid, selected: task.tag == tag) {
                        run { try store.setTag(task.tag == tag ? nil : tag, of: task) }
                    }
                }
            }
        }
        .card()
    }

    private func dueCard(today: DayKey) -> some View {
        let due = task.dueDate
        let custom = due.map { $0 != store.today && $0 != store.tomorrow } ?? false
        return VStack(alignment: .leading, spacing: 10) {
            cardTitle("Échéance")
            FlowLayout(spacing: 6) {
                dueChoice("Aujourd'hui", selected: due == store.today) { run { try store.setDueDate(store.today, of: task) } }
                dueChoice("Demain", selected: due == store.tomorrow) { run { try store.setDueDate(store.tomorrow, of: task) } }
                dueChoice(custom ? DayLabel.text(for: due ?? today, today: today) : "Choisir…", selected: custom,
                          warning: task.isOverdue(today: today)) {
                    dayPicker = DayPickerRequest(kind: .due, task: task)
                }
                dueChoice("Aucune", selected: due == nil) { run { try store.setDueDate(nil, of: task) } }
            }
        }
        .card()
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardTitle("Notes")
            TextField("Ajouter une note…", text: $notes, axis: .vertical)
                .font(.manrope(15, .medium, relativeTo: .body))
                .foregroundStyle(Palette.text)
                .lineLimit(2...10)
                .focused($focusedField, equals: .notes)
        }
        .card()
    }

    /// « Créée via Siri le 9 oct. · reportée 2 fois », et la suppression, discrète.
    private var footer: some View {
        HStack {
            Text(origin)
                .font(.meta)
                .foregroundStyle(Palette.textMuted)
            Spacer()
            Button {
                confirmDelete = true
            } label: {
                Label("Supprimer", systemImage: "trash")
                    .font(.manrope(13, .bold, relativeTo: .footnote))
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .overlay { Capsule().strokeBorder(Palette.border, lineWidth: 1) }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    private var origin: String {
        let source = switch task.source {
        case .siri: "via Siri"
        case .widget: "via le widget"
        case .manual: "dans l'app"
        }
        var text = "Créée \(source) le \(task.createdAt.formatted(.dateTime.day().month(.abbreviated)))"
        if task.postponeCount > 0 {
            text += task.postponeCount == 1 ? " · reportée 1 fois" : " · reportée \(task.postponeCount) fois"
        }
        return text
    }

    // MARK: Choix

    private func choice(_ label: String, symbol: String? = nil, dot: Color? = nil, selected: Bool,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let dot {
                    Circle().fill(dot).frame(width: 8, height: 8)
                }
                if let symbol {
                    Image(systemName: symbol).font(.caption.weight(.semibold))
                }
                Text(label)
            }
            .font(.chip)
            .foregroundStyle(Palette.text)
            .padding(.horizontal, 12)
            .frame(minHeight: 36)
            .background(selected ? Color(hex: 0x2A2A33) : Palette.raised, in: Capsule())
            .overlay { Capsule().strokeBorder(selected ? Palette.text : .clear, lineWidth: 1.5) }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func dueChoice(_ label: String, selected: Bool, warning: Bool = false,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.chip)
                .foregroundStyle(selected ? Palette.onAccent : Palette.textSoft)
                .padding(.horizontal, 12)
                .frame(minHeight: 36)
                .background(selected ? (warning ? Palette.warning : Palette.accent) : Palette.raised, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Enregistrement

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
