import CoreModels
import SwiftData
import SwiftUI
import TimelineEngine

/// Contenu du tiroir : la boîte de réception groupée par section planifiable, prête à glisser.
struct DrawerContent: View {
    let day: DayKey
    let onSelect: (TaskItem) -> Void

    @Environment(\.modelContext) private var context
    @Query(TaskItem.inboxDescriptor) private var tasks: [TaskItem]
    @Query(TaskSection.orderedDescriptor) private var sections: [TaskSection]
    @FocusState private var captureFocused: Bool
    @State private var captureCount = 0
    @State private var addCount = 0

    private var store: TaskStore { TaskStore(context: context) }

    var body: some View {
        let today = store.today
        VStack(spacing: 0) {
            CaptureField(focus: $captureFocused) { title in
                if (try? store.capture(title, source: .manual)) != nil { captureCount += 1 }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.background.opacity(0.6), in: Capsule())
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6, pinnedViews: [.sectionHeaders]) {
                    ForEach(groups, id: \.title) { group in
                        Section {
                            ForEach(group.tasks) { task in
                                row(task, today: today)
                            }
                        } header: {
                            Text(group.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.regularMaterial)
                        }
                    }
                    if tasks.isEmpty {
                        Text("Rien en attente. Capture une idée ci-dessus.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .padding(16)
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: captureCount)
        .sensoryFeedback(.success, trigger: addCount)
    }

    private func row(_ task: TaskItem, today: DayKey) -> some View {
        HStack(spacing: 8) {
            if task.isOverdue(today: today) {
                Circle().fill(Color.gentleWarning).frame(width: 7, height: 7)
                    .accessibilityLabel("Échéance passée")
            }
            Text(task.title)
                .lineLimit(1)
            Spacer(minLength: 4)
            if let due = task.dueDate {
                Text(DayLabel.text(for: due, today: today))
                    .font(.caption)
                    .foregroundStyle(task.isOverdue(today: today) ? Color.gentleWarning : .secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .onTapGesture { onSelect(task) }
        .draggable(TaskDragItem(id: task.id)) {
            Text(task.title)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .contextMenu {
            // Repli garanti si le glisser échoue (ADR-008).
            Button("Ajouter au jour", systemImage: "plus.circle") {
                if (try? store.schedule(task, on: day)) != nil { addCount += 1 }
            }
            Button("Détails", systemImage: "info.circle") { onSelect(task) }
        }
    }

    /// « À trier » puis une section planifiable par groupe ; dans chaque groupe, échéance la plus
    /// proche puis étiquette (Urgent d'abord). Les sections hors planning n'apparaissent pas (ADR-014).
    private var groups: [(title: String, tasks: [TaskItem])] {
        let sorted = tasks.sorted { a, b in
            switch (a.dueDate, b.dueDate) {
            case let (x?, y?) where x != y: return x < y
            case (.some, nil): return true
            case (nil, .some): return false
            default: return rank(a.tag) < rank(b.tag)
            }
        }
        var result: [(title: String, tasks: [TaskItem])] = []
        let unsorted = sorted.filter { $0.sectionId == nil }
        if !unsorted.isEmpty { result.append((title: "À trier", tasks: unsorted)) }
        for section in sections where section.isPlannable {
            let members = sorted.filter { $0.sectionId == section.id }
            if !members.isEmpty { result.append((title: section.name, tasks: members)) }
        }
        return result
    }

    private func rank(_ tag: TaskTag?) -> Int {
        tag?.rank ?? TaskTag.allCases.count
    }
}
