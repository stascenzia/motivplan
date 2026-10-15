import CoreModels
import SwiftData
import SwiftUI
import TimelineEngine

/// Calendrier, mode Semaine (maquette « Calendrier — semaine ») : une carte par jour, du lundi
/// au dimanche, avec les tâches en puces, une barre de charge et le temps prévu. On glisse une
/// puce d'un jour à l'autre ; toucher un jour ouvre sa frise. Le mode Mois arrive en v2.
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
        let tasksByDay = Dictionary(grouping: scheduled.filter(\.isOnDay)) { $0.scheduledDate ?? "" }
        let layouts = Dictionary(uniqueKeysWithValues: days.map { ($0, store.layout(of: tasksByDay[$0] ?? [])) })
        let planned = layouts.values.reduce(0) { $0 + Self.total($1) }
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ScreenHeader(title: "Calendrier") {
                        if !days.contains(today) {
                            Button("Cette semaine") {
                                withAnimation { weekStart = DayKeys.startOfWeek(containing: today) ?? today }
                            }
                            .buttonStyle(PillButtonStyle(prominent: true))
                        }
                    }

                    weekHeader(planned: planned)
                        .padding(.leading, 20)
                        .padding(.trailing, 12)
                        .padding(.top, 14)
                        .padding(.bottom, 6)

                    LazyVStack(spacing: 6) {
                        ForEach(days, id: \.self) { day in
                            DayCard(day: day, today: today, tasks: tasksByDay[day] ?? [],
                                    layout: layouts[day] ?? store.layout(of: []),
                                    store: store, openDay: openDay, moveTo: { task, target in move(task, to: target) },
                                    pickDay: { dayPicker = $0 }, run: run)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
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

    /// « 12 – 18 octobre », « Semaine 42 · 24 h 30 planifiées », flèches.
    private func weekHeader(planned: Minutes) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.blockTitle)
                    .foregroundStyle(Palette.text)
                Text(subtitle(planned: planned))
                    .font(.meta)
                    .foregroundStyle(Palette.textTertiary)
            }
            Spacer()
            RoundIconButton(label: "Semaine précédente", systemImage: "chevron.left", fill: .clear) { shiftWeek(-1) }
            RoundIconButton(label: "Semaine suivante", systemImage: "chevron.right", fill: .clear) { shiftWeek(1) }
        }
    }

    /// « 12 – 18 octobre »
    private var title: String {
        guard let start = DayKeys.date(from: weekStart),
              let endKey = DayKeys.adding(6, to: weekStart), let end = DayKeys.date(from: endKey) else { return "Semaine" }
        return "\(start.formatted(.dateTime.day())) – \(end.formatted(.dateTime.day().month(.wide)))"
    }

    private func subtitle(planned: Minutes) -> String {
        let week = DayKeys.date(from: weekStart).map { Calendar(identifier: .iso8601).component(.weekOfYear, from: $0) }
        let prefix = week.map { "Semaine \($0)" } ?? "Semaine"
        return planned > 0 ? "\(prefix) · \(TimeText.duration(planned)) planifiées" : prefix
    }

    static func total(_ layout: DayLayout) -> Minutes {
        layout.placements.reduce(0) { $0 + $1.end - $1.start }
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

/// Carte d'un jour : lettre et numéro à gauche, puces des tâches et barre de charge au milieu,
/// temps prévu à droite.
private struct DayCard: View {
    let day: DayKey
    let today: DayKey
    let tasks: [TaskItem]
    let layout: DayLayout
    let store: TaskStore
    let openDay: (DayKey) -> Void
    let moveTo: (TaskItem, DayKey) -> Void
    let pickDay: (DayPickerRequest) -> Void
    let run: (() throws -> Void) -> Void

    @State private var targeted = false

    /// Une journée « pleine » pour la barre de charge : 8 heures.
    private static let fullDay: Minutes = 8 * 60

    var body: some View {
        let isToday = day == today
        let total = WeekScreen.total(layout)
        let byId = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
        let date = DayKeys.date(from: day) ?? .now
        HStack(alignment: .center, spacing: 12) {
            Button { openDay(day) } label: {
                VStack(spacing: 0) {
                    Text(date.formatted(.dateTime.weekday(.abbreviated)).uppercased().replacingOccurrences(of: ".", with: ""))
                        .font(.manrope(11, .bold, relativeTo: .caption2))
                        .foregroundStyle(isToday ? Palette.accentSoft : Palette.textTertiary)
                    Text(date.formatted(.dateTime.day()))
                        .font(.manrope(20, .extrabold, relativeTo: .title3).monospacedDigit())
                        .foregroundStyle(Palette.text)
                }
                .frame(width: 44, height: 50)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(heading(date: date, isToday: isToday))
            .accessibilityHint("Ouvre la journée")

            VStack(alignment: .leading, spacing: 7) {
                if layout.placements.isEmpty {
                    Text(targeted ? "Lâche ici" : "Journée libre")
                        .font(.meta)
                        .foregroundStyle(targeted ? Palette.accentSoft : Palette.textFaint)
                } else {
                    FlowLayout(spacing: 5) {
                        ForEach(layout.placements, id: \.id) { placement in
                            if let task = byId[placement.id] {
                                chip(task, placement)
                            }
                        }
                    }
                }
                Capsule()
                    .fill(Palette.control)
                    .frame(height: 4)
                    .overlay(alignment: .leading) {
                        GeometryReader { geometry in
                            Capsule()
                                .fill(isToday ? Palette.accent : Color(hex: 0x5C5C7A))
                                .frame(width: geometry.size.width * min(1, CGFloat(total) / CGFloat(Self.fullDay)))
                        }
                    }
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)

            Text(total > 0 ? TimeText.duration(total) : "—")
                .font(.meta.monospacedDigit())
                .foregroundStyle(isLate ? Palette.warning : Palette.textSecondary)
                .frame(width: 50, alignment: .trailing)
        }
        .padding(.leading, 10)
        .padding(.trailing, 14)
        .frame(minHeight: 70)
        .background(isToday ? Color(hex: 0x1C1C24) : Palette.surface,
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(targeted || isToday ? Palette.accent : Color(hex: 0x1E1E24),
                              lineWidth: targeted ? 2 : isToday ? 1.5 : 1)
        }
        .contentShape(Rectangle())
        .onTapGesture { openDay(day) }
        .dropDestination(for: TaskDragItem.self) { items, _ in
            guard let id = items.first?.id, let task = fetch(id) else { return false }
            moveTo(task, day)
            return true
        } isTargeted: { targeted = $0 }
        .animation(.easeInOut(duration: 0.15), value: targeted)
    }

    private var isLate: Bool {
        (layout.endOfDay ?? 0) > EndOfDayFooter.lateThreshold
    }

    private func chip(_ task: TaskItem, _ placement: Placement) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(placement.isAnchored ? Palette.anchor : TagColors.of(task.tag).vivid)
                .frame(width: 7, height: 7)
            Text(placement.isAnchored ? "\(task.title) \(TimeText.clock(placement.start))" : task.title)
                .strikethrough(task.isDone)
                .lineLimit(1)
        }
        .font(.manrope(12, .semibold, relativeTo: .caption))
        .foregroundStyle(task.isDone ? Palette.textMuted : Palette.textSoft)
        .padding(.horizontal, 9)
        .frame(minHeight: 24)
        .background(Palette.control, in: Capsule())
        .draggable(TaskDragItem(id: task.id)) {
            Text(task.title)
                .font(.manrope(12, .bold, relativeTo: .caption))
                .foregroundStyle(Palette.text)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Palette.control, in: Capsule())
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

    private func heading(date: Date, isToday: Bool) -> String {
        let text = date.formatted(.dateTime.weekday(.wide).day().month(.wide))
        return isToday ? "\(text) · aujourd'hui" : text
    }

    private func fetch(_ id: UUID) -> TaskItem? {
        var descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? store.context.fetch(descriptor).first
    }
}
