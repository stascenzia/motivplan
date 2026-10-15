import CoreModels
import SwiftData
import SwiftUI
import TimelineEngine

/// Boîte de réception (maquette « Boîte de réception ») : capture permanente, une tuile par
/// section avec son nombre de tâches, puis la liste de la tuile choisie. Toucher une tâche
/// la déplie et propose les actions rapides (ADR-014).
struct InboxView: View {
    @Environment(\.modelContext) private var context
    @Query(TaskItem.inboxDescriptor) private var inbox: [TaskItem]
    @Query(TaskSection.orderedDescriptor) private var sections: [TaskSection]
    @FocusState private var captureFocused: Bool
    /// Tuile choisie : `nil` pour « À trier ».
    @State private var selectedSection: UUID?
    @State private var expanded: UUID?
    @State private var dayPicker: DayPickerRequest?
    @State private var reviewing: TaskItem?
    @State private var editingSection: SectionEditing?
    @State private var errorMessage: String?
    @State private var captureCount = 0
    @State private var scheduleCount = 0

    private var store: TaskStore { TaskStore(context: context) }

    var body: some View {
        let today = store.today
        let section = sections.first { $0.id == selectedSection }
        let items = inbox.filter { $0.sectionId == section?.id }
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeader(title: "Boîte de réception", subtitle: "Tout est noté. Trie quand tu veux.")

                CaptureField(focus: $captureFocused) { title in
                    run {
                        let task = try store.capture(title, source: .manual)
                        if let section { try store.setSection(section, of: task) }
                        captureCount += 1
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                tiles
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                listHeader(section)
                    .padding(.horizontal, 20)
                    .padding(.top, 22)
                    .padding(.bottom, 8)

                LazyVStack(spacing: 6) {
                    ForEach(items) { task in
                        row(task, section: section, today: today)
                    }
                    if items.isEmpty {
                        Text(section == nil ? "Rien à trier. Tout est rangé." : "Rien à faire ici pour l'instant.")
                            .font(.subtitle)
                            .foregroundStyle(Palette.textTertiary)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .overlay {
                                RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                                    .strokeBorder(Palette.border, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, TabBarMetrics.contentInset)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: TaskItem.self) { task in
            TaskDetailView(task: task)
                .hidesTabBar()
        }
        .navigationDestination(for: TaskSection.self) { section in
            SectionView(section: section)
                .hidesTabBar()
        }
        .sheet(item: $dayPicker) { request in
            DayPickerSheet(title: request.title, initial: request.task.dueDate ?? store.today) { day in
                switch request.kind {
                case .schedule: schedule(request.task, on: day)
                case .due: run { try store.setDueDate(day, of: request.task) }
                }
            }
        }
        .sheet(item: $reviewing) { task in
            ReviewSheet(task: task) { review, note in run { try store.complete(task, review: review, note: note) } }
        }
        .sheet(item: $editingSection) { editing in
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
        .sensoryFeedback(.impact(weight: .light), trigger: captureCount)
        .sensoryFeedback(.success, trigger: scheduleCount)
        .sensoryFeedback(.selection, trigger: selectedSection)
        // Une section supprimée ailleurs : retour sur « À trier ».
        .onChange(of: sections.map(\.id)) { _, ids in
            if let selectedSection, !ids.contains(selectedSection) { self.selectedSection = nil }
        }
    }

    // MARK: Tuiles

    private var tiles: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            tile(name: "À trier", symbol: "tray", count: inbox.filter { $0.sectionId == nil }.count, id: nil)
            ForEach(sections) { section in
                tile(name: section.name, symbol: section.symbol,
                     count: inbox.filter { $0.sectionId == section.id }.count, id: section.id)
                    .contextMenu {
                        Button("Modifier", systemImage: "slider.horizontal.3") {
                            editingSection = SectionEditing(section: section)
                        }
                        if let index = sections.firstIndex(where: { $0.id == section.id }) {
                            if index > 0 {
                                Button("Déplacer avant", systemImage: "arrow.left") {
                                    run { try store.moveSection(section, to: index - 1) }
                                }
                            }
                            if index < sections.count - 1 {
                                Button("Déplacer après", systemImage: "arrow.right") {
                                    run { try store.moveSection(section, to: index + 1) }
                                }
                            }
                        }
                    }
            }
            Button {
                editingSection = SectionEditing(section: nil)
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                    Text("Nouvelle section")
                        .font(.manrope(12, .bold, relativeTo: .caption))
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(Palette.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 84)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Palette.border, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func tile(name: String, symbol: String, count: Int, id: UUID?) -> some View {
        let selected = selectedSection == id
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedSection = id
                expanded = nil
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(selected ? Palette.accent : Palette.textSecondary)
                        .frame(width: 26, height: 26)
                        .background(Palette.control, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    Spacer(minLength: 2)
                    Text("\(count)")
                        .font(.manrope(20, .extrabold, relativeTo: .title3).monospacedDigit())
                        .foregroundStyle(count > 0 ? Palette.text : Palette.textFaint)
                }
                Spacer(minLength: 6)
                Text(name)
                    .font(.manrope(12, .bold, relativeTo: .caption))
                    .foregroundStyle(Color(hex: 0xC9C9D1))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
            .background(selected ? Palette.field : Palette.surface,
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(selected ? Palette.accent : Palette.hairline, lineWidth: selected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(name), \(count)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func listHeader(_ section: TaskSection?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(section?.name ?? "À trier")
                .font(.manrope(17, .extrabold, relativeTo: .headline))
                .foregroundStyle(Palette.text)
            Spacer()
            if let section {
                NavigationLink(value: section) {
                    HStack(spacing: 4) {
                        Text(section.keepsMemory ? "Section et mémoire" : "Voir la section")
                        Image(systemName: "chevron.forward")
                    }
                    .font(.manrope(12, .bold, relativeTo: .caption))
                    .foregroundStyle(Palette.accentSoft)
                }
            } else {
                Text("Touche une tâche pour la ranger")
                    .font(.meta)
                    .foregroundStyle(Palette.textTertiary)
            }
        }
    }

    // MARK: Lignes

    private func row(_ task: TaskItem, section: TaskSection?, today: DayKey) -> some View {
        let open = expanded == task.id
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(duration: 0.28)) { expanded = open ? nil : task.id }
            } label: {
                TaskRow(task: task, today: today)
            }
            .buttonStyle(.plain)
            .accessibilityHint(open ? "Replie les actions" : "Affiche les actions")

            if open {
                quickActions(task, section: section)
                    .padding(.leading, 60)
                    .padding(.trailing, 14)
                    .padding(.bottom, 14)
                    .transition(.opacity)
            }
        }
        .background(open ? Palette.raised : Palette.surface,
                    in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
        .contextMenu {
            TaskActionsMenu(task: task, store: store, sections: sections, pickDay: { dayPicker = $0 },
                            finish: finish, run: run)
        }
    }

    private func quickActions(_ task: TaskItem, section: TaskSection?) -> some View {
        FlowLayout(spacing: 6) {
            if section?.isPlannable ?? true {
                Button("Aujourd'hui") { schedule(task, on: store.today) }
                    .buttonStyle(PillButtonStyle(prominent: true))
                Button("Demain") { schedule(task, on: store.tomorrow) }
                    .buttonStyle(PillButtonStyle())
                Button("Planifier le…") { dayPicker = DayPickerRequest(kind: .schedule, task: task) }
                    .buttonStyle(PillButtonStyle())
            } else {
                Button(section?.keepsMemory == true ? "C'est fait…" : "Terminer") { finish(task) }
                    .buttonStyle(PillButtonStyle(prominent: true))
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
                Text("Ranger").pill()
            }
            Menu {
                Button("Aujourd'hui") { run { try store.setDueDate(store.today, of: task) } }
                Button("Demain") { run { try store.setDueDate(store.tomorrow, of: task) } }
                Button("Cette semaine") { run { try store.setDueDate(store.endOfThisWeek, of: task) } }
                Button("Choisir…") { dayPicker = DayPickerRequest(kind: .due, task: task) }
                if task.dueDate != nil {
                    Button("Retirer l'échéance", systemImage: "xmark") { run { try store.setDueDate(nil, of: task) } }
                }
            } label: {
                Text("Échéance").pill()
            }
            NavigationLink(value: task) {
                Text("Détail")
                    .font(.manrope(12, .bold, relativeTo: .footnote))
                    .foregroundStyle(Palette.textSoft)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 34)
                    .overlay { Capsule().strokeBorder(Palette.borderStrong, lineWidth: 1) }
            }
            .buttonStyle(.plain)
        }
    }

    private func finish(_ task: TaskItem) {
        if sections.section(of: task)?.keepsMemory == true {
            reviewing = task
        } else {
            run { try store.toggleDone(task) }
        }
    }

    private func schedule(_ task: TaskItem, on day: DayKey) {
        run {
            try store.schedule(task, on: day)
            scheduleCount += 1
            expanded = nil
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

/// Ouverture de l'éditeur de section (`nil` : nouvelle section).
struct SectionEditing: Identifiable {
    let section: TaskSection?
    var id: String { section.map { "\($0.id)" } ?? "new" }
}
