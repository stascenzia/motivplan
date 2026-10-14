import CoreModels
import SwiftData
import SwiftUI
import TimelineEngine

/// Vue Semaine provisoire (lot 6) : une carte par jour, du lundi au dimanche. On glisse une tâche
/// d'un jour à l'autre ; toucher l'en-tête d'un jour ouvre sa frise. Forme définitive au design.
struct WeekScreen: View {
    let openDay: (DayKey) -> Void

    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<TaskItem> { $0.deletedAt == nil && $0.scheduledDate != nil })
    private var scheduled: [TaskItem]
    @State private var weekStart = DayKeys.startOfWeek(containing: DayKeys.key(for: .now)) ?? DayKeys.key(for: .now)
    @State private var dayPicker: DayPickerRequest?
    @State private var errorMessage: String?
    @State private var moveCount = 0

    private var store: TaskStore { TaskStore(context: context) }

    var body: some View {
        let today = store.today
        let days = (0..<7).compactMap { DayKeys.adding($0, to: weekStart) }
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(days, id: \.self) { day in
                        DayCard(day: day, today: today, tasks: scheduled.filter { $0.scheduledDate == day && $0.isOnDay },
                                store: store, openDay: openDay, moveTo: { task, target in move(task, to: target) },
                                pickDay: { dayPicker = $0 }, run: run)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button("Semaine précédente", systemImage: "chevron.left") { shiftWeek(-1) }
                    Button("Semaine suivante", systemImage: "chevron.right") { shiftWeek(1) }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !days.contains(today) {
                        Button("Cette semaine") {
                            withAnimation { weekStart = DayKeys.startOfWeek(containing: today) ?? today }
                        }
                    }
                }
            }
            .sheet(item: $dayPicker) { request in
                DayPickerSheet(title: "Déplacer au…", initial: request.task.scheduledDate ?? today) { day in
                    move(request.task, to: day)
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
            .sensoryFeedback(.success, trigger: moveCount)
        }
    }

    /// « 12 – 18 oct. »
    private var title: String {
        guard let start = DayKeys.date(from: weekStart),
              let endKey = DayKeys.adding(6, to: weekStart), let end = DayKeys.date(from: endKey) else { return "Semaine" }
        let startText = start.formatted(.dateTime.day())
        let endText = end.formatted(.dateTime.day().month(.abbreviated))
        return "\(startText) – \(endText)"
    }

    private func shiftWeek(_ weeks: Int) {
        guard let next = DayKeys.adding(7 * weeks, to: weekStart) else { return }
        withAnimation(.easeInOut(duration: 0.2)) { weekStart = next }
    }

    /// Changement de jour : la tâche passe en fin de séquence, une ancre garde son heure (plan, lot 6).
    private func move(_ task: TaskItem, to day: DayKey) {
        guard task.scheduledDate != day else { return }
        run { try store.schedule(task, on: day) }
        moveCount += 1
    }

    private func run(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Carte d'un jour : en-tête avec la charge, puis les tâches en puces, dans l'ordre de la journée.
private struct DayCard: View {
    let day: DayKey
    let today: DayKey
    let tasks: [TaskItem]
    let store: TaskStore
    let openDay: (DayKey) -> Void
    let moveTo: (TaskItem, DayKey) -> Void
    let pickDay: (DayPickerRequest) -> Void
    let run: (() throws -> Void) -> Void

    @State private var targeted = false

    var body: some View {
        let layout = store.layout(of: tasks)
        let byId = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
        VStack(alignment: .leading, spacing: 10) {
            Button { openDay(day) } label: {
                HStack(alignment: .firstTextBaseline) {
                    Text(heading)
                        .font(.headline)
                        .foregroundStyle(day == today ? Color.accentColor : .primary)
                    Spacer()
                    Text(load(layout))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(isLate(layout) ? Color.gentleWarning : .secondary)
                    Image(systemName: "chevron.forward")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Ouvre la journée")

            if layout.placements.isEmpty {
                Text(targeted ? "Lâche ici" : "Rien de prévu")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(layout.placements, id: \.id) { placement in
                        if let task = byId[placement.id] {
                            chip(task, placement)
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(targeted ? Color.accentColor : .clear, lineWidth: 2)
        }
        .dropDestination(for: TaskDragItem.self) { items, _ in
            guard let id = items.first?.id, let task = fetch(id) else { return false }
            moveTo(task, day)
            return true
        } isTargeted: { targeted = $0 }
        .animation(.easeInOut(duration: 0.15), value: targeted)
    }

    private func chip(_ task: TaskItem, _ placement: Placement) -> some View {
        HStack(spacing: 5) {
            if placement.isAnchored {
                Text(TimeText.clock(placement.start))
                    .font(.caption2.monospacedDigit().weight(.semibold))
            }
            Text(task.title)
                .font(.caption)
                .strikethrough(task.isDone)
                .lineLimit(1)
        }
        .foregroundStyle(task.isDone ? .secondary : .primary)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background((task.tag?.tint ?? .gray).opacity(0.18), in: Capsule())
        .draggable(TaskDragItem(id: task.id)) {
            Text(task.title)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.regularMaterial, in: Capsule())
        }
        .contextMenu {
            // Repli garanti si le glisser échoue (ADR-008).
            if let next = DayKeys.adding(1, to: day) {
                Button("Jour suivant", systemImage: "arrow.right") { moveTo(task, next) }
            }
            Button("Déplacer au…", systemImage: "calendar") { pickDay(DayPickerRequest(kind: .schedule, task: task)) }
            Button("Remettre dans la boîte", systemImage: "tray.and.arrow.down") { run { try store.unschedule(task) } }
        }
    }

    private var heading: String {
        guard let date = DayKeys.date(from: day) else { return day }
        let text = date.formatted(.dateTime.weekday(.wide).day())
        return day == today ? "\(text) · aujourd'hui" : text.capitalized
    }

    /// Charge du jour : temps prévu et heure de fin.
    private func load(_ layout: DayLayout) -> String {
        guard let end = layout.endOfDay else { return "" }
        let total = layout.placements.reduce(0) { $0 + $1.end - $1.start }
        return "\(TimeText.duration(total)) · fin \(TimeText.clock(end))"
    }

    private func isLate(_ layout: DayLayout) -> Bool {
        (layout.endOfDay ?? 0) > 22 * 60
    }

    private func fetch(_ id: UUID) -> TaskItem? {
        var descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? store.context.fetch(descriptor).first
    }
}

/// Puces qui passent à la ligne.
private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(proposal: proposal, subviews: subviews)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(proposal: ProposedViewSize(width: bounds.width, height: nil), subviews: subviews) {
            for item in row.items {
                subviews[item.index].place(at: CGPoint(x: bounds.minX + item.x, y: bounds.minY + row.y),
                                           proposal: ProposedViewSize(item.size))
            }
        }
    }

    private struct Row {
        var y: CGFloat
        var height: CGFloat = 0
        var items: [(index: Int, x: CGFloat, size: CGSize)] = []
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        let maxWidth = proposal.width ?? .infinity
        var rows = [Row(y: 0)]
        var x: CGFloat = 0
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            let width = min(size.width, maxWidth)
            if x > 0, x + width > maxWidth {
                let last = rows[rows.count - 1]
                rows.append(Row(y: last.y + last.height + spacing))
                x = 0
            }
            rows[rows.count - 1].items.append((index, x, CGSize(width: width, height: size.height)))
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
            x += width + spacing
        }
        return rows
    }
}
