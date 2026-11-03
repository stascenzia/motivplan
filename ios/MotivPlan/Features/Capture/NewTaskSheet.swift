import CoreModels
import SwiftData
import SwiftUI
import TimelineEngine

/// Création complète depuis le bouton « + » : titre, section, jour, durée, étiquette, échéance,
/// notes. Créée dans l'app, l'entrée est rangée tout de suite dans sa section (ADR-015) ; la capture
/// rapide (widget, Siri, champ de la boîte) reste un simple titre qui part dans « À trier ».
/// Les champs suivent le type de la section : dates pour une période, juste un titre pour un article.
struct NewTaskSheet: View {
    /// Section proposée à l'ouverture.
    let initialSection: UUID?

    private enum DateField: String, Identifiable {
        case day, due
        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(TaskSection.orderedDescriptor) private var sections: [TaskSection]
    @FocusState private var titleFocused: Bool
    @State private var draft = TaskDraft()
    @State private var picking: DateField?
    @State private var errorMessage: String?
    @State private var createdCount = 0
    @State private var periodStart = Date.now
    @State private var periodEnd = Date.now

    private var store: TaskStore { TaskStore(context: context) }

    var body: some View {
        let today = store.today
        let section = sections.first { $0.id == draft.sectionId }
        let kind = section?.kind ?? .tasks
        let plannable = section?.isDayPlannable ?? true
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    TextField(kind.titlePrompt, text: $draft.title, axis: .vertical)
                        .font(.manrope(24, .extrabold, relativeTo: .title))
                        .tracking(-0.4)
                        .foregroundStyle(Palette.text)
                        .focused($titleFocused)
                        .submitLabel(.done)
                        .onSubmit { titleFocused = false }
                        .accessibilityIdentifier("new-task-title")
                        .padding(.horizontal, 4)
                        .padding(.bottom, 4)

                    sectionCard
                    switch kind {
                    case .tasks:
                        if plannable {
                            dayCard(today: today, section: section)
                            durationCard(section: section)
                        }
                        tagCard
                        dueCard(today: today)
                    case .memory:
                        tagCard
                    case .periods:
                        periodCard
                    case .checklist:
                        EmptyView()
                    }
                    notesCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .screenBackground()
            .navigationTitle(kind.newTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter", action: create)
                        .disabled(!canCreate)
                        .accessibilityIdentifier("new-task-add")
                }
            }
            .sheet(item: $picking) { field in
                DayPickerSheet(title: field == .day ? "Planifier le…" : "Échéance",
                               initial: (field == .day ? draft.scheduledDate : draft.dueDate) ?? today) { day in
                    switch field {
                    case .day: draft.scheduledDate = day
                    case .due: draft.dueDate = day
                    }
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
        .sensoryFeedback(.success, trigger: createdCount)
        .onAppear {
            draft.sectionId = initialSection
        }
        .task {
            // Sur iOS 17, le focus au premier rendu peut demander un léger différé (plan, §Capture).
            try? await Task.sleep(for: .milliseconds(150))
            titleFocused = true
        }
    }

    private var canCreate: Bool {
        !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: Cartes

    /// La to-do d'abord, puis les listes de la mémoire (ADR-015).
    private var sectionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardTitle(text: "À faire")
            FlowLayout(spacing: 6) {
                ChoiceChip(label: "À trier", symbol: "tray", selected: draft.sectionId == nil) {
                    draft.sectionId = nil
                }
                ForEach(sections.filter { $0.kind == .tasks }) { section in
                    sectionChip(section)
                }
            }
            let lists = sections.filter(\.kind.isMemorySpace)
            if !lists.isEmpty {
                CardTitle(text: "Mémoire")
                    .padding(.top, 4)
                FlowLayout(spacing: 6) {
                    ForEach(lists) { section in
                        sectionChip(section)
                    }
                }
            }
        }
        .card()
    }

    private func sectionChip(_ section: TaskSection) -> some View {
        ChoiceChip(label: section.name, symbol: section.symbol, selected: draft.sectionId == section.id) {
            draft.sectionId = section.id
        }
    }

    /// Premier et dernier jour, inclus. Une période ne va jamais dans la journée.
    private var periodCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardTitle(text: "Dates")
            DatePicker("Du", selection: $periodStart, displayedComponents: .date)
                .onChange(of: periodStart) { _, start in
                    if periodEnd < start { periodEnd = start }
                }
            DatePicker("Au", selection: $periodEnd, in: periodStart..., displayedComponents: .date)
            Text("Visible dans le calendrier, jamais dans ta journée.")
                .font(.meta)
                .foregroundStyle(Palette.textTertiary)
        }
        .font(.rowTitle)
        .foregroundStyle(Palette.text)
        .tint(Palette.accent)
        .card()
    }

    private func dayCard(today: DayKey, section: TaskSection?) -> some View {
        let day = draft.scheduledDate
        let tomorrow = DayKeys.adding(1, to: today)
        let custom = day.map { $0 != today && $0 != tomorrow } ?? false
        return VStack(alignment: .leading, spacing: 10) {
            CardTitle(text: "Jour")
            if section?.repeatRule == .daily {
                Text("Posée seule dans ta journée chaque matin.")
                    .font(.meta)
                    .foregroundStyle(Palette.textTertiary)
            } else {
                FlowLayout(spacing: 6) {
                    DateChoiceChip(label: "Plus tard", selected: day == nil) { draft.scheduledDate = nil }
                    DateChoiceChip(label: "Aujourd'hui", selected: day == today) { draft.scheduledDate = today }
                        .accessibilityIdentifier("new-task-today")
                    DateChoiceChip(label: "Demain", selected: day == tomorrow) { draft.scheduledDate = tomorrow }
                    DateChoiceChip(label: custom ? DayLabel.text(for: day ?? today, today: today) : "Choisir…",
                                   selected: custom) { picking = .day }
                }
            }
        }
        .card()
    }

    /// Durée par pas de 15 min (principe 4). Sans choix, celle de la section.
    private func durationCard(section: TaskSection?) -> some View {
        let suggested = Durations.defaultDuration(existing: nil, suggested: section?.defaultDuration)
        let duration = draft.durationMin ?? suggested
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                CardTitle(text: "Durée")
                Text(draft.durationMin == nil ? "Suggérée par la section" : "Par pas de 15 min")
                    .font(.meta)
                    .foregroundStyle(Palette.textTertiary)
            }
            Spacer()
            StepButton(text: "−", label: "Moins 15 minutes") {
                draft.durationMin = max(duration - 15, Durations.minimum)
            }
            .disabled(duration <= Durations.minimum)
            Text(TimeText.duration(duration))
                .font(.manrope(20, .extrabold, relativeTo: .title3).monospacedDigit())
                .foregroundStyle(draft.durationMin == nil ? Palette.textSecondary : Palette.text)
                .frame(minWidth: 76)
                .accessibilityLabel("Durée \(TimeText.duration(duration))")
            StepButton(text: "+", label: "Plus 15 minutes") {
                draft.durationMin = duration + 15
            }
        }
        .card()
    }

    private var tagCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardTitle(text: "Étiquette")
            FlowLayout(spacing: 6) {
                ForEach(TaskTag.allCases, id: \.self) { tag in
                    ChoiceChip(label: tag.label, dot: TagColors.of(tag).vivid, selected: draft.tag == tag) {
                        draft.tag = draft.tag == tag ? nil : tag
                    }
                }
            }
        }
        .card()
    }

    private func dueCard(today: DayKey) -> some View {
        let due = draft.dueDate
        let tomorrow = DayKeys.adding(1, to: today)
        let endOfWeek = store.endOfThisWeek
        let custom = due.map { $0 != today && $0 != tomorrow && $0 != endOfWeek } ?? false
        return VStack(alignment: .leading, spacing: 10) {
            CardTitle(text: "Échéance")
            FlowLayout(spacing: 6) {
                DateChoiceChip(label: "Aucune", selected: due == nil) { draft.dueDate = nil }
                DateChoiceChip(label: "Aujourd'hui", selected: due == today) { draft.dueDate = today }
                DateChoiceChip(label: "Demain", selected: due == tomorrow) { draft.dueDate = tomorrow }
                if endOfWeek != today && endOfWeek != tomorrow {
                    DateChoiceChip(label: "Cette semaine", selected: due == endOfWeek) { draft.dueDate = endOfWeek }
                }
                DateChoiceChip(label: custom ? DayLabel.text(for: due ?? today, today: today) : "Choisir…",
                               selected: custom) { picking = .due }
            }
        }
        .card()
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            CardTitle(text: "Notes")
            TextField("Ajouter une note…", text: $draft.notes, axis: .vertical)
                .font(.manrope(15, .medium, relativeTo: .body))
                .foregroundStyle(Palette.text)
                .lineLimit(2...10)
        }
        .card()
    }

    // MARK: Création

    /// Ne garde que les champs du type de la section choisie.
    private func create() {
        guard canCreate else { return }
        var draft = draft
        let kind = sections.first { $0.id == draft.sectionId }?.kind ?? .tasks
        if kind != .tasks {
            draft.scheduledDate = nil
            draft.durationMin = nil
            draft.dueDate = nil
        }
        if kind == .checklist || kind == .periods { draft.tag = nil }
        if kind == .periods {
            draft.startDate = DayKeys.key(for: periodStart)
            draft.endDate = DayKeys.key(for: max(periodEnd, periodStart))
        }
        do {
            try store.create(draft)
            createdCount += 1
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
