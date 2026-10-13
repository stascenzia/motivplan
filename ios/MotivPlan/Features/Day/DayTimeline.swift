import CoreModels
import SwiftData
import SwiftUI
import TimelineEngine

/// Frise d'un jour : bulles placées par le moteur, réordonnancement par geste maison,
/// dépôt depuis le tiroir.
///
/// Réordonnancement (ADR-008) : appui long → la bulle se soulève → elle suit le doigt ;
/// la position visée se calcule sur la géométrie des autres bulles ; la frise montre en direct
/// les heures recalculées et la place réservée ; défilement automatique près des bords.
struct DayTimeline: View {
    let day: DayKey
    @Binding var drawerDetent: DrawerDetent
    let onSelect: (TaskItem) -> Void

    @Environment(\.modelContext) private var context
    @Query private var rows: [TaskItem]
    @State private var drag: DragState?
    @State private var frames: [UUID: CGRect] = [:]
    @State private var viewportHeight: CGFloat = 0
    @State private var autoScroll: Task<Void, Never>?
    @State private var liftCount = 0
    @State private var dropCount = 0
    @State private var doneCount = 0
    @State private var errorMessage: String?

    private static let space = "timeline"
    private static let edgeZone: CGFloat = 70

    private struct DragState {
        let id: UUID
        var fingerY: CGFloat
        var target: Int
        let height: CGFloat
        let grabOffset: CGFloat
    }

    init(day: DayKey, drawerDetent: Binding<DrawerDetent>, onSelect: @escaping (TaskItem) -> Void) {
        self.day = day
        self._drawerDetent = drawerDetent
        self.onSelect = onSelect
        self._rows = Query(TaskItem.dayDescriptor(day))
    }

    private var store: TaskStore { TaskStore(context: context) }

    var body: some View {
        let dayTasks = rows.filter(\.isOnDay)
        let byId = Dictionary(uniqueKeysWithValues: dayTasks.map { ($0.id, $0) })
        let layout = previewLayout(of: dayTasks)

        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(layout.placements, id: \.id) { placement in
                        if placement.gapBefore > 0 {
                            GapView(minutes: placement.gapBefore)
                        }
                        if let task = byId[placement.id] {
                            row(task, placement, layout: layout, proxy: proxy)
                        }
                    }
                    if !layout.placements.isEmpty {
                        EndOfDayFooter(layout: layout)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                // Laisse la fin de journée visible au-dessus du tiroir replié.
                .padding(.bottom, 160)
            }
            .coordinateSpace(name: Self.space)
            .scrollDisabled(drag != nil)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { viewportHeight = $0 }
            .overlay(alignment: .top) { floatingBubble(byId: byId, layout: layout) }
            .overlay {
                if dayTasks.isEmpty {
                    ContentUnavailableView("Journée libre", systemImage: "sun.max",
                                           description: Text("Glisse une tâche depuis le tiroir."))
                        .allowsHitTesting(false)
                        .padding(.bottom, 140)
                }
            }
            .dropDestination(for: TaskDragItem.self) { items, location in
                drop(items, at: location.y, layout: layout)
            } isTargeted: { targeted in
                if targeted { drawerDetent = .peek }
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: liftCount)
        .sensoryFeedback(.success, trigger: dropCount)
        .sensoryFeedback(.success, trigger: doneCount)
        .alert("Action impossible", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: Lignes

    private func row(_ task: TaskItem, _ placement: Placement, layout: DayLayout,
                     proxy: ScrollViewProxy) -> some View {
        let isDragged = drag?.id == task.id
        return HStack(alignment: .top, spacing: 10) {
            Text(TimeText.clock(placement.start))
                .font(.caption.monospacedDigit())
                .foregroundStyle(placement.isAnchored ? .primary : .secondary)
                .frame(width: 44, alignment: .trailing)
                .padding(.top, 12)
            TaskBubble(task: task, placement: placement) { toggle(task) }
                .opacity(isDragged ? 0 : 1)
                .overlay {
                    if isDragged {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.accentColor.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    }
                }
        }
        .padding(.vertical, 3)
        .id(placement.id)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { frames[placement.id] = $0 }
        .contentShape(Rectangle())
        .onTapGesture { onSelect(task) }
        .simultaneousGesture(reorderGesture(task, placement: placement, layout: layout, proxy: proxy),
                             including: placement.isAnchored ? .subviews : .all)
        .animation(.spring(duration: 0.28), value: placement.start)
        .accessibilityAction(named: "Ouvrir") { onSelect(task) }
    }

    /// Copie de la bulle soulevée, qui suit le doigt.
    @ViewBuilder
    private func floatingBubble(byId: [UUID: TaskItem], layout: DayLayout) -> some View {
        if let drag, let task = byId[drag.id], let placement = layout.placements.first(where: { $0.id == drag.id }) {
            HStack(alignment: .top, spacing: 10) {
                Color.clear.frame(width: 44)
                TaskBubble(task: task, placement: placement) {}
                    .scaleEffect(1.03)
                    .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
            }
            .padding(.horizontal, 16)
            .offset(y: drag.fingerY - drag.grabOffset)
            .allowsHitTesting(false)
        }
    }

    // MARK: Réordonnancement

    private func reorderGesture(_ task: TaskItem, placement: Placement, layout: DayLayout,
                                proxy: ScrollViewProxy) -> some Gesture {
        LongPressGesture(minimumDuration: 0.35)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space)))
            .onChanged { value in
                guard case .second(true, let dragValue) = value else { return }
                guard let dragValue else {
                    // Appui long reconnu, le doigt n'a pas encore bougé : on soulève.
                    if drag == nil, let frame = frames[task.id] {
                        drag = DragState(id: task.id, fingerY: frame.midY,
                                         target: layout.sequence.firstIndex(of: task.id) ?? 0,
                                         height: frame.height, grabOffset: frame.height / 2)
                        liftCount += 1
                    }
                    return
                }
                let y = dragValue.location.y
                if drag == nil, let frame = frames[task.id] {
                    drag = DragState(id: task.id, fingerY: y,
                                     target: layout.sequence.firstIndex(of: task.id) ?? 0,
                                     height: frame.height, grabOffset: y - frame.minY)
                    liftCount += 1
                }
                drag?.fingerY = y
                updateTarget(sequence: layout.sequence)
                handleEdges(proxy: proxy, sequence: layout.sequence)
            }
            .onEnded { _ in
                autoScroll?.cancel()
                autoScroll = nil
                guard let finished = drag else { return }
                drag = nil
                run { try store.move(task, to: finished.target) }
                dropCount += 1
            }
    }

    /// Position visée : nombre d'autres bulles dont le milieu est au-dessus du doigt.
    private func updateTarget(sequence: [UUID]) {
        guard let current = drag else { return }
        let target = sequence
            .filter { $0 != current.id }
            .filter { (frames[$0]?.midY ?? .infinity) < current.fingerY }
            .count
        if target != current.target {
            withAnimation(.spring(duration: 0.25)) { drag?.target = target }
        }
    }

    /// Défilement automatique tant que le doigt reste près d'un bord.
    private func handleEdges(proxy: ScrollViewProxy, sequence: [UUID]) {
        guard let current = drag, viewportHeight > 0 else { return }
        let direction = current.fingerY > viewportHeight - Self.edgeZone ? 1
            : current.fingerY < Self.edgeZone ? -1 : 0
        guard direction != 0 else {
            autoScroll?.cancel()
            autoScroll = nil
            return
        }
        guard autoScroll == nil else { return }
        autoScroll = Task { @MainActor in
            while !Task.isCancelled, drag != nil {
                let visible = sequence.filter { id in
                    guard let frame = frames[id] else { return false }
                    return frame.maxY > 0 && frame.minY < viewportHeight
                }
                let edgeId = direction > 0 ? visible.last : visible.first
                if let edgeId, let index = sequence.firstIndex(of: edgeId) {
                    let next = index + direction
                    if sequence.indices.contains(next) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo(sequence[next], anchor: direction > 0 ? .bottom : .top)
                        }
                    }
                }
                try? await Task.sleep(for: .milliseconds(300))
                updateTarget(sequence: sequence)
            }
        }
    }

    /// Pendant un glisser, la frise montre la séquence visée avec ses heures recalculées.
    private func previewLayout(of dayTasks: [TaskItem]) -> DayLayout {
        var items = dayTasks.compactMap(\.timelineItem)
        let dayStart = store.settings.dayStart
        if let drag {
            let changes = Sequencing.move(id: drag.id, to: drag.target, in: items, dayStart: dayStart)
            items = items.map { item in
                var copy = item
                copy.orderIndex = changes[item.id] ?? item.orderIndex
                return copy
            }
        }
        return TimelineEngine.layoutDay(dayStart: dayStart, items: items)
    }

    // MARK: Dépôt depuis le tiroir

    private func drop(_ items: [TaskDragItem], at y: CGFloat, layout: DayLayout) -> Bool {
        guard let item = items.first else { return false }
        let id = item.id
        var descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let task = try? context.fetch(descriptor).first else { return false }
        let position = layout.sequence.filter { (frames[$0]?.midY ?? .infinity) < y }.count
        run { try store.place(task, on: day, at: position) }
        dropCount += 1
        return true
    }

    private func toggle(_ task: TaskItem) {
        let wasDone = task.isDone
        withAnimation(.spring(duration: 0.35)) {
            run { try store.toggleDone(task) }
        }
        if !wasDone { doneCount += 1 }
    }

    private func run(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Fin prévue de la journée. Signal discret si une ancre a poussé des tâches ou si la journée déborde.
struct EndOfDayFooter: View {
    let layout: DayLayout

    private static let lateThreshold: Minutes = 22 * 60

    var body: some View {
        let end = layout.endOfDay ?? 0
        let crowded = layout.totalPushedMinutes > 0 || layout.placements.contains(where: \.overlapsAnchor)
        let late = end > Self.lateThreshold
        HStack(spacing: 6) {
            Image(systemName: late ? "moon.zzz" : "flag.checkered")
            Text(end >= 24 * 60 ? "Fin prévue après minuit" : "Fin prévue \(TimeText.clock(end))")
            if layout.totalPushedMinutes > 0 {
                Text("· \(TimeText.duration(layout.totalPushedMinutes)) de décalage")
            } else if crowded {
                Text("· ancres qui se chevauchent")
            }
        }
        .font(.caption)
        .foregroundStyle(late || crowded ? Color.gentleWarning : .secondary)
        .padding(.leading, 54)
        .padding(.top, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
