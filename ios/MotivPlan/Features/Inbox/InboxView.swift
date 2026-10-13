import CoreModels
import SwiftData
import SwiftUI
import TimelineEngine

/// Boîte de réception : champ de capture permanent, liste, gestes rapides.
struct InboxView: View {
    @Binding var captureRequested: Bool

    @Environment(\.modelContext) private var context
    @Query(TaskItem.inboxDescriptor) private var tasks: [TaskItem]
    @FocusState private var captureFocused: Bool
    @State private var captureSource: TaskSource = .manual
    @State private var dayPicker: DayPickerRequest?
    @State private var errorMessage: String?
    @State private var captureCount = 0
    @State private var scheduleCount = 0

    private var store: TaskStore { TaskStore(context: context) }

    var body: some View {
        let today = store.today
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

            Section {
                ForEach(tasks) { task in
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
                        TaskActionsMenu(task: task, store: store, pickDay: { dayPicker = $0 }, run: run)
                    }
                }
            } footer: {
                if !tasks.isEmpty {
                    Text("Glisse vers la gauche pour planifier, appui long pour le reste.")
                }
            }
        }
        .overlay {
            if tasks.isEmpty {
                ContentUnavailableView("Boîte vide", systemImage: "tray",
                                       description: Text("Note ici ce qui te passe par la tête."))
                    .allowsHitTesting(false)
                    .padding(.top, 120)
            }
        }
        .navigationTitle("Boîte de réception")
        .navigationDestination(for: TaskItem.self) { task in
            TaskDetailView(task: task)
        }
        .sheet(item: $dayPicker) { request in
            DayPickerSheet(title: request.title, initial: request.task.dueDate ?? store.today) { day in
                switch request.kind {
                case .schedule: schedule(request.task, on: day)
                case .due: run { try store.setDueDate(day, of: request.task) }
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
