import CoreModels
import SwiftData
import SwiftUI
import TimelineEngine

/// Frise d'un jour : capsules placées par le moteur, réordonnancement par geste maison,
/// dépôt depuis le tiroir.
///
/// Réordonnancement (ADR-008) : appui long → la tâche se soulève → elle suit le doigt ;
/// la position visée se calcule sur la géométrie des autres lignes ; la frise montre en direct
/// les heures recalculées et la place réservée ; défilement automatique près des bords.
struct DayTimeline: View {
    let day: DayKey
    let isToday: Bool
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

    init(day: DayKey, isToday: Bool, drawerDetent: Binding<DrawerDetent>, onSelect: @escaping (TaskItem) -> Void) {
        self.day = day
        self.isToday = isToday
        self._drawerDetent = drawerDetent
        self.onSelect = onSelect
        self._rows = Query(TaskItem.dayDescriptor(day))
    }

    private var store: TaskStore { TaskStore(context: context) }

    var body: some View {
        let dayTasks = rows.filter(\.isOnDay)
        let byId = Dictionary(uniqueKeysWithValues: dayTasks.map { ($0.id, $0) })
        let layout = previewLayout(of: dayTasks)

        VStack(spacing: 0) {
            if !dayTasks.isEmpty {
                summary(dayTasks, layout: layout)
            }
            TimelineView(.everyMinute) { context in
                let now = isToday ? Self.minutes(of: context.date) : nil
                ScrollViewReader { proxy in
                    ScrollView {
                        content(layout: layout, byId: byId, now: now, proxy: proxy)
                    }
                    .coordinateSpace(name: Self.space)
                    .scrollDisabled(drag != nil)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { viewportHeight = $0 }
                    .overlay(alignment: .top) { floatingBubble(byId: byId, layout: layout) }
                    .overlay {
                        if dayTasks.isEmpty {
                            emptyDay
                        }
                    }
                    .dropDestination(for: TaskDragItem.self) { items, location in
                        drop(items, at: location.y, layout: layout)
                    } isTargeted: { targeted in
                        if targeted { drawerDetent = .peek }
                    }
                }
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

    private func content(layout: DayLayout, byId: [UUID: TaskItem], now: Minutes?,
                         proxy: ScrollViewProxy) -> some View {
        let nowIndex = now.map { Self.nowIndex(in: layout, now: $0) }
        return VStack(spacing: 0) {
            ForEach(Array(layout.placements.enumerated()), id: \.element.id) { index, placement in
                if placement.gapBefore > 0 {
                    GapView(minutes: placement.gapBefore)
                }
                if let now, nowIndex == index {
                    NowLine(minutes: now)
                }
                if let task = byId[placement.id] {
                    row(task, placement, now: now, layout: layout, proxy: proxy)
                }
            }
            if let now, !layout.placements.isEmpty, nowIndex == layout.placements.count {
                NowLine(minutes: now)
            }
            if !layout.placements.isEmpty {
                EndOfDayFooter(layout: layout)
            }
        }
        // Axe vertical qui relie les capsules.
        .background(alignment: .topLeading) {
            if !layout.placements.isEmpty {
                Rectangle()
                    .fill(Palette.control)
                    .frame(width: 2)
                    .padding(.leading, 44 + 10 + TaskBubble.capsuleWidth / 2 - 1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 14)
        // Laisse la fin de journée visible au-dessus du tiroir replié.
        .padding(.bottom, 100)
    }

    /// Puces du haut : tâches faites, heure de fin prévue.
    private func summary(_ dayTasks: [TaskItem], layout: DayLayout) -> some View {
        let done = dayTasks.filter(\.isDone).count
        return HStack(spacing: 8) {
            Chip(text: done == 1 ? "1 faite" : "\(done) faites", systemImage: "checkmark",
                 tone: done > 0 ? .accent : .neutral, height: 32)
            if let end = layout.endOfDay {
                Chip(text: end >= 24 * 60 ? "Fin après minuit" : "Fin vers \(TimeText.clock(end))",
                     systemImage: "clock", tone: end > EndOfDayFooter.lateThreshold ? .warning : .neutral,
                     height: 32)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }

    private var emptyDay: some View {
        VStack(spacing: 10) {
            Image(systemName: "sun.max")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Palette.accent)
            Text("Journée libre")
                .font(.blockTitle)
                .foregroundStyle(Palette.text)
            Text("Glisse une tâche depuis le tiroir.")
                .font(.subtitle)
                .foregroundStyle(Palette.textSecondary)
        }
        .multilineTextAlignment(.center)
        .allowsHitTesting(false)
        .padding(.bottom, 120)
    }

    /// Minute de la journée (0 à 1439).
    static func minutes(of date: Date, calendar: Calendar = .current) -> Minutes {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    /// La ligne « maintenant » se place avant la première tâche qui n'est pas encore finie.
    static func nowIndex(in layout: DayLayout, now: Minutes) -> Int {
        layout.placements.firstIndex { $0.end > now } ?? layout.placements.count
    }

    // MARK: Lignes

    private func row(_ task: TaskItem, _ placement: Placement, now: Minutes?, layout: DayLayout,
                     proxy: ScrollViewProxy) -> some View {
        let isDragged = drag?.id == task.id
        let current = now.map { placement.start <= $0 && $0 < placement.end && !task.isDone } ?? false
        let strong = placement.isAnchored || current
        return HStack(alignment: .top, spacing: 10) {
            Text(TimeText.clock(placement.start))
                .font(.manrope(12, strong ? .extrabold : .semibold, relativeTo: .caption).monospacedDigit())
                .foregroundStyle(task.isDone ? Palette.textMuted : strong ? Palette.text : Palette.textSecondary)
                .frame(width: 44, alignment: .trailing)
                .padding(.top, 6)
            if isDragged {
                dropSlot(placement)
            } else {
                TaskBubble(task: task, placement: placement, now: now) { toggle(task) }
            }
        }
        .padding(.vertical, 4)
        .id(placement.id)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { frames[placement.id] = $0 }
        .contentShape(Rectangle())
        .onTapGesture { onSelect(task) }
        .simultaneousGesture(reorderGesture(task, placement: placement, layout: layout, proxy: proxy),
                             including: placement.isAnchored ? .subviews : .all)
        .animation(.spring(duration: 0.28), value: placement.start)
        .accessibilityAction(named: "Ouvrir") { onSelect(task) }
    }

    /// Place réservée pendant un glisser : « Déposer ici · 16:15 – 16:30 ».
    private func dropSlot(_ placement: Placement) -> some View {
        let height = TaskBubble.capsuleHeight(placement.end - placement.start)
        let shape = RoundedRectangle(cornerRadius: TaskBubble.capsuleWidth / 2, style: .continuous)
        return HStack(spacing: 10) {
            shape
                .fill(Palette.accent.opacity(0.08))
                .overlay { shape.strokeBorder(Palette.accent, style: StrokeStyle(lineWidth: 2, dash: [6, 4])) }
                .frame(width: TaskBubble.capsuleWidth, height: height)
            Text("Déposer ici · \(TimeText.clock(placement.start)) – \(TimeText.clock(placement.end))")
                .font(.chip)
                .foregroundStyle(Palette.accentSoft)
            Spacer(minLength: 0)
        }
        .frame(minHeight: height)
    }

    /// Copie de la tâche soulevée, qui suit le doigt, légèrement inclinée.
    @ViewBuilder
    private func floatingBubble(byId: [UUID: TaskItem], layout: DayLayout) -> some View {
        if let drag, let task = byId[drag.id], let placement = layout.placements.first(where: { $0.id == drag.id }) {
            HStack(spacing: 12) {
                Circle().fill(TagColors.of(task.tag).vivid).frame(width: 10, height: 10)
                Text(task.title)
                    .font(.manrope(15, .bold, relativeTo: .body))
                    .foregroundStyle(Palette.text)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(TimeText.duration(placement.end - placement.start))
                    .font(.meta)
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(.horizontal, 16)
            .frame(height: 64)
            .background(Palette.control, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Palette.borderStrong, lineWidth: 1)
            }
            .rotationEffect(.degrees(-2))
            .shadow(color: .black.opacity(0.6), radius: 24, y: 24)
            .padding(.leading, 44)
            .padding(.trailing, 36)
            .offset(y: drag.fingerY - 32)
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

    /// Position visée : nombre d'autres lignes dont le milieu est au-dessus du doigt.
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

    static let lateThreshold: Minutes = 22 * 60

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
        .font(.meta)
        .foregroundStyle(late || crowded ? Palette.warning : Palette.textTertiary)
        .padding(.leading, 54)
        .padding(.top, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
