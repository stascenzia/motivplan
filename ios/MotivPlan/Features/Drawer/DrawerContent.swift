import CoreModels
import SwiftData
import SwiftUI
import TimelineEngine

/// Contenu du tiroir ouvert (maquette « tiroir ouvert ») : capture, filtres par section, puis
/// la boîte de réception groupée par section planifiable, prête à glisser dans la journée.
struct DrawerContent: View {
    let day: DayKey
    let onSelect: (TaskItem) -> Void
    let onClose: () -> Void

    @Environment(\.modelContext) private var context
    @Query(TaskItem.inboxDescriptor) private var tasks: [TaskItem]
    @Query(TaskSection.orderedDescriptor) private var sections: [TaskSection]
    @FocusState private var captureFocused: Bool
    @State private var filter: Filter = .all
    @State private var captureCount = 0
    @State private var addCount = 0

    private enum Filter: Hashable {
        case all, unsorted, section(UUID)
    }

    private struct TaskGroup {
        let filter: Filter
        let title: String
        let symbol: String?
        let tasks: [TaskItem]
    }

    private var store: TaskStore { TaskStore(context: context) }

    var body: some View {
        let today = store.today
        let groups = self.groups
        let total = groups.reduce(0) { $0 + $1.tasks.count }
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Tiroir")
                    .font(.manrope(22, .extrabold, relativeTo: .title2))
                    .foregroundStyle(Palette.text)
                Text("\(total)")
                    .font(.manrope(14, .bold, relativeTo: .subheadline))
                    .foregroundStyle(Palette.textTertiary)
                Spacer()
                RoundIconButton(label: "Refermer le tiroir", systemImage: "chevron.down", fill: Palette.field,
                                action: onClose)
            }
            .padding(.horizontal, 16)

            CaptureField(focus: $captureFocused, placeholder: "Ajouter une tâche…",
                         identifier: "drawer-capture-field", fill: Palette.field) { title in
                if (try? store.capture(title, source: .manual)) != nil { captureCount += 1 }
            }
            .padding(.horizontal, 16)

            filters(groups, total: total)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(groups.filter { filter == .all || $0.filter == filter }, id: \.title) { group in
                        VStack(alignment: .leading, spacing: 6) {
                            GroupLabel(text: group.title, systemImage: group.symbol)
                            ForEach(group.tasks) { task in
                                row(task, today: today)
                            }
                        }
                    }
                    if tasks.isEmpty {
                        Text("Rien en attente. Capture une idée ci-dessus.")
                            .font(.subtitle)
                            .foregroundStyle(Palette.textSecondary)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: captureCount)
        .sensoryFeedback(.success, trigger: addCount)
    }

    private func filters(_ groups: [TaskGroup], total: Int) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(.all, label: "Toutes", count: total)
                ForEach(groups, id: \.title) { group in
                    filterChip(group.filter, label: group.title, count: group.tasks.count)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func filterChip(_ value: Filter, label: String, count: Int) -> some View {
        let selected = filter == value
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { filter = value }
        } label: {
            HStack(spacing: 6) {
                Text(label)
                Text("\(count)").opacity(0.6).monospacedDigit()
            }
            .font(.chip)
            .foregroundStyle(selected ? Palette.onAccent : Palette.textSoft)
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .background(selected ? Palette.text : Palette.field, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func row(_ task: TaskItem, today: DayKey) -> some View {
        let section = sections.section(of: task)
        let minutes = Durations.defaultDuration(existing: task.durationMin, suggested: section?.defaultDuration)
        return HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.textFaint)
                .frame(width: 22)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.taskTitle)
                    .foregroundStyle(Palette.text)
                    .lineLimit(2)
                if task.dueDate != nil || task.tag != nil {
                    HStack(spacing: 6) {
                        if let due = task.dueDate {
                            Chip(text: DayLabel.text(for: due, today: today), tone: dueTone(due, today: today))
                        }
                        if let tag = task.tag {
                            Chip(text: tag.label, dot: TagColors.of(tag).vivid)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(TimeText.duration(minutes))
                .font(.meta.monospacedDigit())
                .foregroundStyle(Palette.textTertiary)
        }
        .padding(.leading, 6)
        .padding(.trailing, 12)
        .padding(.vertical, 8)
        .frame(minHeight: 56)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { onSelect(task) }
        .draggable(TaskDragItem(id: task.id)) {
            HStack(spacing: 10) {
                Circle().fill(TagColors.of(task.tag).vivid).frame(width: 10, height: 10)
                Text(task.title).font(.manrope(15, .bold, relativeTo: .body))
                Text(TimeText.duration(minutes)).font(.meta)
            }
            .foregroundStyle(Palette.text)
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(Palette.control, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .contextMenu {
            // Repli garanti si le glisser échoue (ADR-008).
            Button("Ajouter au jour", systemImage: "plus.circle") {
                if (try? store.schedule(task, on: day)) != nil { addCount += 1 }
            }
            Button("Détails", systemImage: "info.circle") { onSelect(task) }
        }
    }

    /// Aujourd'hui en accent, passée en ambre (jamais de rouge), plus tard en gris.
    private func dueTone(_ due: DayKey, today: DayKey) -> Chip.Tone {
        due < today ? .warning : due == today ? .accent : .neutral
    }

    /// « À trier » puis une section planifiable par groupe ; dans chaque groupe, échéance la plus
    /// proche puis étiquette (Urgent d'abord). Les sections hors planning n'apparaissent pas (ADR-014).
    private var groups: [TaskGroup] {
        let sorted = tasks.sorted { a, b in
            switch (a.dueDate, b.dueDate) {
            case let (x?, y?) where x != y: return x < y
            case (.some, nil): return true
            case (nil, .some): return false
            default: return rank(a.tag) < rank(b.tag)
            }
        }
        var result: [TaskGroup] = []
        let unsorted = sorted.filter { $0.sectionId == nil }
        if !unsorted.isEmpty {
            result.append(TaskGroup(filter: .unsorted, title: "À trier", symbol: "tray", tasks: unsorted))
        }
        for section in sections where section.isPlannable {
            let members = sorted.filter { $0.sectionId == section.id }
            if !members.isEmpty {
                result.append(TaskGroup(filter: .section(section.id), title: section.name, symbol: section.symbol,
                                    tasks: members))
            }
        }
        return result
    }

    private func rank(_ tag: TaskTag?) -> Int {
        tag?.rank ?? TaskTag.allCases.count
    }
}
