import CoreModels
import SwiftData
import SwiftUI
import TimelineEngine

/// Onglet Mémoire (ADR-015) : tout ce qui n'est pas une tâche à caser dans la journée. Envies avec
/// avis (films, recettes), listes à cocher (courses), périodes datées (voyages). Une tuile par
/// liste, puis le contenu de la liste choisie, présenté selon son type.
struct MemoryScreen: View {
    /// Liste ouverte, gardée par la coque : le « + » y range la nouvelle entrée.
    @Binding var selection: UUID?

    @Environment(\.modelContext) private var context
    @Query(TaskSection.orderedDescriptor) private var sections: [TaskSection]
    @Query(filter: #Predicate<TaskItem> { $0.deletedAt == nil && $0.sectionId != nil },
           sort: [SortDescriptor(\.createdAt, order: .reverse)])
    private var items: [TaskItem]
    @FocusState private var captureFocused: Bool
    @State private var showMemory = false
    @State private var reviewing: TaskItem?
    @State private var dayPicker: DayPickerRequest?
    @State private var editingSection: SectionEditing?
    @State private var newEntry: NewTaskRequest?
    @State private var confirmClear = false
    @State private var errorMessage: String?
    @State private var doneCount = 0
    @State private var checkCount = 0

    private var store: TaskStore { TaskStore(context: context) }

    var body: some View {
        let today = store.today
        let lists = sections.filter(\.kind.isMemorySpace)
        let current = lists.first { $0.id == selection } ?? lists.first
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ScreenHeader(title: "Mémoire", subtitle: "Tes envies, tes listes, tes voyages.")

                    tiles(lists, current: current, today: today)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    if let current {
                        content(current, today: today)
                            .padding(.horizontal, 16)
                            .padding(.top, 22)
                    } else {
                        emptyText("Crée une liste pour tes films, tes recettes, tes courses ou tes voyages.")
                            .padding(16)
                    }
                }
                .padding(.bottom, TabBarMetrics.contentInset)
            }
            .scrollDismissesKeyboard(.interactively)
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: TaskItem.self) { task in
                TaskDetailView(task: task)
                    .hidesTabBar()
            }
            .sheet(item: $reviewing) { task in
                ReviewSheet(task: task) { review, note in
                    run { try store.complete(task, review: review, note: note) }
                    doneCount += 1
                }
            }
            .sheet(item: $dayPicker) { request in
                DayPickerSheet(title: request.title, initial: store.today) { day in
                    run { try store.schedule(request.task, on: day) }
                    doneCount += 1
                }
            }
            .sheet(item: $editingSection) { editing in
                SectionEditor(section: editing.section, defaultKind: .memory)
            }
            .sheet(item: $newEntry) { request in
                NewTaskSheet(initialSection: request.section)
                    .presentationDragIndicator(.visible)
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
            .sensoryFeedback(.selection, trigger: checkCount)
            .sensoryFeedback(.selection, trigger: selection)
        }
    }

    // MARK: Tuiles

    private func tiles(_ lists: [TaskSection], current: TaskSection?, today: DayKey) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(lists) { list in
                SectionTile(name: list.name, symbol: list.symbol, count: count(of: list, today: today),
                            colors: colors(of: list), selected: current?.id == list.id) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selection = list.id
                        showMemory = false
                    }
                }
                .contextMenu {
                    Button("Modifier", systemImage: "slider.horizontal.3") {
                        editingSection = SectionEditing(section: list)
                    }
                }
            }
            NewSectionTile(title: "Nouvelle liste") { editingSection = SectionEditing(section: nil) }
        }
    }

    /// Ce qui reste : envies pas encore faites, articles pas cochés, périodes à venir ou en cours.
    private func count(of list: TaskSection, today: DayKey) -> Int {
        let own = items.filter { $0.sectionId == list.id }
        switch list.kind {
        case .periods: return own.filter { ($0.periodEnd ?? today) >= today }.count
        default: return own.filter { $0.status == .inbox || $0.status == .scheduled }.count
        }
    }

    /// Même couleur que la tuile de la section partout : sa place dans la liste complète.
    private func colors(of list: TaskSection) -> TagColors {
        SectionColors.at(sections.firstIndex { $0.id == list.id } ?? 0)
    }

    // MARK: Contenu

    @ViewBuilder
    private func content(_ list: TaskSection, today: DayKey) -> some View {
        let own = items.filter { $0.sectionId == list.id }
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(list.name)
                    .font(.manrope(17, .extrabold, relativeTo: .headline))
                    .foregroundStyle(Palette.text)
                Spacer()
                Button("Modifier") { editingSection = SectionEditing(section: list) }
                    .font(.manrope(12, .bold, relativeTo: .caption))
                    .foregroundStyle(Palette.accentSoft)
            }
            .padding(.horizontal, 4)

            switch list.kind {
            case .memory: memoryList(list, items: own, today: today)
            case .checklist: checklist(list, items: own, today: today)
            case .periods: periodList(list, items: own, today: today)
            case .tasks: EmptyView()
            }
        }
    }

    /// Envies avec avis : à faire (planifiables à la demande), puis la mémoire, datée et notée.
    @ViewBuilder
    private func memoryList(_ list: TaskSection, items own: [TaskItem], today: DayKey) -> some View {
        let todo = own.filter { $0.status == .inbox || $0.status == .scheduled }
        let memory = own.filter(\.isDone).sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        capture(list, placeholder: "Un film, une recette à essayer…")
        HStack(spacing: 2) {
            modeButton("À faire · \(todo.count)", selected: !showMemory) { showMemory = false }
            modeButton("Mémoire · \(memory.count)", selected: showMemory) { showMemory = true }
        }
        .padding(4)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

        VStack(spacing: 6) {
            if showMemory {
                ForEach(memory) { task in
                    NavigationLink(value: task) {
                        MemoryRow(task: task, today: today)
                            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Remettre à faire", systemImage: "arrow.uturn.backward") { run { try store.toggleDone(task) } }
                    }
                }
                if memory.isEmpty {
                    emptyText("Rien encore. Ce que tu termines ici est gardé avec ton avis.")
                }
            } else {
                ForEach(todo) { task in
                    memoryTodoRow(task, today: today)
                }
                if todo.isEmpty {
                    emptyText("Rien en attente. Note une envie juste au-dessus.")
                }
            }
        }
    }

    private func memoryTodoRow(_ task: TaskItem, today: DayKey) -> some View {
        HStack(spacing: 0) {
            NavigationLink(value: task) {
                TaskRow(task: task, today: today)
            }
            .buttonStyle(.plain)
            Menu {
                Button("Aujourd'hui", systemImage: "sun.max") { plan(task, on: store.today) }
                Button("Demain", systemImage: "sunrise") { plan(task, on: store.tomorrow) }
                Button("Planifier le…", systemImage: "calendar") { dayPicker = DayPickerRequest(kind: .schedule, task: task) }
                if task.scheduledDate != nil {
                    Button("Retirer du jour", systemImage: "tray.and.arrow.down") { run { try store.unschedule(task) } }
                }
            } label: {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.accent)
                    .frame(width: 40, height: 44)
            }
            .accessibilityLabel("Planifier")
            Button {
                reviewing = task
            } label: {
                Circle()
                    .strokeBorder(Palette.ring, lineWidth: 2)
                    .frame(width: 26, height: 26)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("C'est fait…")
            .padding(.trailing, 6)
        }
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
        .contextMenu {
            Button("C'est fait…", systemImage: "checkmark.circle") { reviewing = task }
            Button("Supprimer", systemImage: "trash", role: .destructive) { run { try store.delete(task) } }
        }
    }

    /// Liste à cocher : on coche en magasin, les cochés descendent, puis on les vide.
    @ViewBuilder
    private func checklist(_ list: TaskSection, items own: [TaskItem], today: DayKey) -> some View {
        let open = own.filter { !$0.isDone }
        let checked = own.filter(\.isDone)
        capture(list, placeholder: "Un article…")
        VStack(spacing: 6) {
            ForEach(open) { item in checkRow(item, checked: false) }
            if open.isEmpty {
                emptyText(checked.isEmpty ? "Liste vide. Ajoute un article juste au-dessus." : "Tout est dans le panier !")
            }
            if !checked.isEmpty {
                HStack {
                    GroupLabel(text: "Dans le panier · \(checked.count)")
                    Spacer()
                    Button("Vider les cochés") { confirmClear = true }
                        .buttonStyle(PillButtonStyle())
                }
                .padding(.top, 10)
                ForEach(checked) { item in checkRow(item, checked: true) }
            }
        }
        .confirmationDialog("Retirer les \(checked.count) articles cochés ?", isPresented: $confirmClear,
                            titleVisibility: .visible) {
            Button("Vider les cochés", role: .destructive) { run { try store.clearChecked(in: list) } }
        }
    }

    private func checkRow(_ item: TaskItem, checked: Bool) -> some View {
        let colors = SectionColors.at(sections.firstIndex { $0.id == item.sectionId } ?? 0)
        return Button {
            withAnimation(.spring(duration: 0.3)) { run { try store.toggleDone(item) } }
            checkCount += 1
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    if checked {
                        Circle().fill(colors.vivid)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(Palette.onAccent)
                    } else {
                        Circle().strokeBorder(Palette.ring, lineWidth: 2)
                    }
                }
                .frame(width: 26, height: 26)
                Text(item.title)
                    .font(.taskTitle)
                    .strikethrough(checked)
                    .foregroundStyle(checked ? Palette.textMuted : Palette.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(checked ? .isSelected : [])
        .contextMenu {
            Button("Supprimer", systemImage: "trash", role: .destructive) { run { try store.delete(item) } }
        }
    }

    /// Périodes : à venir et en cours d'abord, puis sans dates, puis passées.
    @ViewBuilder
    private func periodList(_ list: TaskSection, items own: [TaskItem], today: DayKey) -> some View {
        let dated = own.filter { $0.startDate != nil }.sorted { ($0.startDate ?? "") < ($1.startDate ?? "") }
        let upcoming = dated.filter { ($0.periodEnd ?? today) >= today }
        let past = dated.filter { ($0.periodEnd ?? today) < today }.reversed()
        let undated = own.filter { $0.startDate == nil }
        Button {
            newEntry = NewTaskRequest(section: list.id)
        } label: {
            Label("Nouvelle période", systemImage: "plus")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PillButtonStyle(prominent: true))
        .accessibilityIdentifier("memory-new-period")

        VStack(spacing: 6) {
            ForEach(upcoming) { item in periodRow(item, today: today) }
            if upcoming.isEmpty {
                emptyText("Aucune période prévue. Un voyage, des vacances ?")
            }
            if !undated.isEmpty {
                GroupLabel(text: "Dates à choisir")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)
                ForEach(undated) { item in periodRow(item, today: today) }
            }
            if !past.isEmpty {
                GroupLabel(text: "Passées")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)
                ForEach(Array(past)) { item in periodRow(item, today: today) }
            }
        }
    }

    private func periodRow(_ item: TaskItem, today: DayKey) -> some View {
        let colors = SectionColors.of(item.id)
        let isPast = (item.periodEnd ?? today) < today
        return NavigationLink(value: item) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(colors.vivid)
                    .frame(width: 6, height: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.taskTitle)
                        .foregroundStyle(isPast ? Palette.textSecondary : Palette.text)
                    if let start = item.startDate {
                        Text("\(PeriodLabel.range(start: start, end: item.endDate, today: today)) · \(PeriodLabel.relative(start: start, end: item.endDate, today: today))")
                            .font(.meta)
                            .foregroundStyle(Palette.textTertiary)
                    } else {
                        Text("Touche pour choisir les dates")
                            .font(.meta)
                            .foregroundStyle(Palette.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.forward")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.textFaint)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 58)
            .background(isPast ? Palette.surfaceLow : Palette.surface,
                        in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Supprimer", systemImage: "trash", role: .destructive) { run { try store.delete(item) } }
        }
    }

    // MARK: Briques

    /// Créée ici, l'entrée est rangée directement dans la liste (ADR-015).
    private func capture(_ list: TaskSection, placeholder: String) -> some View {
        CaptureField(focus: $captureFocused, placeholder: placeholder, identifier: "memory-capture-field") { title in
            run { try store.create(TaskDraft(title: title, sectionId: list.id)) }
        }
    }

    private func modeButton(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { action() }
        } label: {
            Text(label)
                .font(.manrope(13, selected ? .extrabold : .bold, relativeTo: .footnote))
                .foregroundStyle(selected ? Palette.onAccent : Palette.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(selected ? Palette.accent : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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

    private func plan(_ task: TaskItem, on day: DayKey) {
        run { try store.schedule(task, on: day) }
        doneCount += 1
    }

    private func run(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
