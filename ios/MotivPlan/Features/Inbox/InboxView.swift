import CoreModels
import SwiftData
import SwiftUI
import TimelineEngine

/// Boîte de réception : capture permanente, « À trier », puis une ligne par section (ADR-014).
struct InboxView: View {
    @Binding var captureRequested: Bool

    @Environment(\.modelContext) private var context
    @Query(TaskItem.inboxDescriptor) private var inbox: [TaskItem]
    @Query(TaskSection.orderedDescriptor) private var sections: [TaskSection]
    @FocusState private var captureFocused: Bool
    @State private var captureSource: TaskSource = .manual
    @State private var dayPicker: DayPickerRequest?
    @State private var reviewing: TaskItem?
    @State private var editingSection: SectionEditing?
    @State private var errorMessage: String?
    @State private var captureCount = 0
    @State private var scheduleCount = 0

    private var store: TaskStore { TaskStore(context: context) }

    var body: some View {
        let today = store.today
        let unsorted = inbox.filter { $0.sectionId == nil }
        List {
            Section {
                CaptureField(focus: $captureFocused) { title in
                    run {
                        try store.capture(title, source: captureSource)
                        captureSource = .manual
                        captureCount += 1
                    }
                }
            }

            if !unsorted.isEmpty {
                Section {
                    ForEach(unsorted) { task in
                        row(task, today: today)
                    }
                } header: {
                    Text("À trier")
                } footer: {
                    Text("Appui long pour ranger dans une section, glisser vers la gauche pour planifier.")
                }
            }

            Section {
                ForEach(sections) { section in
                    NavigationLink(value: section) {
                        SectionRow(section: section, count: inbox.filter { $0.sectionId == section.id }.count)
                    }
                }
                .onMove { from, to in
                    guard let index = from.first else { return }
                    run { try store.moveSection(sections[index], to: to > index ? to - 1 : to) }
                }
                Button("Nouvelle section", systemImage: "plus") { editingSection = SectionEditing(section: nil) }
            } header: {
                Text("Sections")
            }
        }
        .navigationTitle("Boîte de réception")
        .navigationDestination(for: TaskItem.self) { task in
            TaskDetailView(task: task)
        }
        .navigationDestination(for: TaskSection.self) { section in
            SectionView(section: section)
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
        .onChange(of: captureRequested, initial: true) { _, requested in
            guard requested else { return }
            captureSource = .widget
            // Sur iOS 17, le focus au premier rendu peut demander un léger différé (plan, §Capture).
            Task {
                try? await Task.sleep(for: .milliseconds(150))
                captureFocused = true
                captureRequested = false
            }
        }
        .onChange(of: captureFocused) { _, focused in
            if !focused { captureSource = .manual }
        }
    }

    private func row(_ task: TaskItem, today: DayKey) -> some View {
        NavigationLink(value: task) {
            TaskRow(task: task, today: today)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("Aujourd'hui", systemImage: "sun.max") { schedule(task, on: store.today) }
                .tint(.accentColor)
            Button("Demain", systemImage: "sunrise") { schedule(task, on: store.tomorrow) }
                .tint(.indigo)
        }
        .swipeActions(edge: .leading) {
            Button("Planifier le…", systemImage: "calendar") {
                dayPicker = DayPickerRequest(kind: .schedule, task: task)
            }
            .tint(.teal)
        }
        .contextMenu {
            TaskActionsMenu(task: task, store: store, sections: sections, pickDay: { dayPicker = $0 },
                            finish: finish, run: run)
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

struct SectionRow: View {
    let section: TaskSection
    let count: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: section.symbol)
                .foregroundStyle(.tint)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(section.name)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if count > 0 {
                Text("\(count)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if section.isPlannable {
            if section.repeatRule != .none { parts.append(section.repeatRule.label) }
        } else {
            parts.append("Hors planning")
        }
        if section.keepsMemory { parts.append("Mémoire") }
        return parts.isEmpty ? "Ponctuelle" : parts.joined(separator: " · ")
    }
}
