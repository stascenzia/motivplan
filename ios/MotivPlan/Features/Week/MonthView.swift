import CoreModels
import SwiftUI
import TimelineEngine

/// Calendrier, mode Mois (ADR-015) : une grille de semaines, la charge de chaque jour, et les
/// périodes (voyages) en bandeaux qui traversent leurs jours. Sert à voir de loin : « dans combien
/// de semaines est ce week-end ? ». Toucher un jour ouvre sa frise.
struct MonthView: View {
    /// Premier jour du mois affiché.
    @Binding var monthStart: DayKey
    let today: DayKey
    /// Tâches posées, par jour.
    let tasksByDay: [DayKey: [TaskItem]]
    let periods: [TaskItem]
    let store: TaskStore
    let openDay: (DayKey) -> Void

    /// Une journée « pleine » pour la barre de charge : 8 heures, comme en vue Semaine.
    private static let fullDay: Minutes = 8 * 60
    private static let maxLanes = 2

    var body: some View {
        let weeks = Self.weeks(of: monthStart)
        VStack(alignment: .leading, spacing: 10) {
            header(weeks: weeks)
            HStack(spacing: 4) {
                ForEach(Array(["L", "M", "M", "J", "V", "S", "D"].enumerated()), id: \.offset) { _, letter in
                    Text(letter)
                        .font(.manrope(11, .bold, relativeTo: .caption2))
                        .foregroundStyle(Palette.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)
            VStack(spacing: 4) {
                ForEach(weeks, id: \.self) { week in
                    weekRow(week)
                }
            }
            upcoming
        }
        // Balayer change de mois ; le défilement vertical reste libre.
        .simultaneousGesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    if value.translation.width < -40 { shift(1) }
                    if value.translation.width > 40 { shift(-1) }
                }
        )
    }

    // MARK: En-tête

    private func header(weeks: [[DayKey]]) -> some View {
        let days = weeks.flatMap { $0 }.filter { $0.prefix(7) == monthStart.prefix(7) }
        let planned = days.reduce(0) { $0 + WeekScreen.total(store.layout(of: tasksByDay[$1] ?? [])) }
        return HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.blockTitle)
                    .foregroundStyle(Palette.text)
                Text(planned > 0 ? "\(TimeText.duration(planned)) planifiées" : "Rien de planifié pour l'instant")
                    .font(.meta)
                    .foregroundStyle(Palette.textTertiary)
            }
            Spacer()
            RoundIconButton(label: "Mois précédent", systemImage: "chevron.left", fill: .clear) { shift(-1) }
            RoundIconButton(label: "Mois suivant", systemImage: "chevron.right", fill: .clear) { shift(1) }
        }
        .padding(.leading, 4)
    }

    /// « Novembre 2026 »
    private var title: String {
        guard let date = DayKeys.date(from: monthStart) else { return "Mois" }
        return date.formatted(.dateTime.month(.wide).year()).capitalized
    }

    // MARK: Semaines

    private func weekRow(_ week: [DayKey]) -> some View {
        let lanes = Self.lanes(for: periods, in: week)
        return HStack(spacing: 4) {
            ForEach(week, id: \.self) { day in
                dayCell(day, periodTitles: lanes.flatMap { $0 }.filter { $0.covers(day) }.map(\.task.title))
            }
        }
        .overlay(alignment: .topLeading) {
            GeometryReader { geometry in
                let cell = (geometry.size.width - 4 * 6) / 7
                ForEach(Array(lanes.prefix(Self.maxLanes).enumerated()), id: \.offset) { lane, bars in
                    ForEach(bars, id: \.task.id) { bar in
                        banner(bar)
                            .frame(width: CGFloat(bar.last - bar.first + 1) * (cell + 4) - 4 - 4, height: 15)
                            .offset(x: CGFloat(bar.first) * (cell + 4) + 2, y: 28 + CGFloat(lane) * 17)
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }

    private func dayCell(_ day: DayKey, periodTitles: [String]) -> some View {
        let inMonth = day.prefix(7) == monthStart.prefix(7)
        let isToday = day == today
        let total = WeekScreen.total(store.layout(of: tasksByDay[day] ?? []))
        let date = DayKeys.date(from: day) ?? .now
        return Button { openDay(day) } label: {
            VStack(spacing: 0) {
                Text(date.formatted(.dateTime.day()))
                    .font(.manrope(13, isToday ? .extrabold : .bold, relativeTo: .footnote).monospacedDigit())
                    .foregroundStyle(isToday ? Palette.onAccent : inMonth ? Palette.text : Palette.textFaint)
                    .frame(width: 24, height: 24)
                    .background(isToday ? Palette.accent : .clear, in: Circle())
                    .padding(.top, 3)
                Spacer(minLength: 0)
                Capsule()
                    .fill(Palette.control)
                    .frame(height: 4)
                    .overlay(alignment: .leading) {
                        GeometryReader { geometry in
                            Capsule()
                                .fill(isToday ? Palette.accent : Palette.loadBar)
                                .frame(width: geometry.size.width * min(1, CGFloat(total) / CGFloat(Self.fullDay)))
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.bottom, 7)
                    .opacity(total > 0 ? 1 : 0)
            }
            .frame(maxWidth: .infinity, minHeight: 74)
            .background(inMonth ? Palette.surface : Palette.surfaceLow,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isToday ? Palette.accent : .clear, lineWidth: 1.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label(date: date, isToday: isToday, total: total, periods: periodTitles))
        .accessibilityHint("Ouvre la journée")
    }

    private func banner(_ bar: Bar) -> some View {
        let colors = SectionColors.of(bar.task.id)
        return Text(bar.task.title)
            .font(.manrope(10, .extrabold, relativeTo: .caption2))
            .foregroundStyle(Palette.onAccent)
            .lineLimit(1)
            .padding(.horizontal, 5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(colors.vivid, in: UnevenRoundedRectangle(
                topLeadingRadius: bar.startsHere ? 7 : 2, bottomLeadingRadius: bar.startsHere ? 7 : 2,
                bottomTrailingRadius: bar.endsHere ? 7 : 2, topTrailingRadius: bar.endsHere ? 7 : 2,
                style: .continuous))
    }

    /// Prochaines périodes, à combien de semaines : la question qui a fait naître cette vue.
    @ViewBuilder
    private var upcoming: some View {
        let next = periods.filter { ($0.periodEnd ?? today) >= today }.prefix(3)
        if !next.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                GroupLabel(text: "À venir")
                ForEach(Array(next)) { period in
                    if let start = period.startDate {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(SectionColors.of(period.id).vivid)
                                .frame(width: 8, height: 8)
                            Text(period.title)
                                .font(.rowTitle)
                                .foregroundStyle(Palette.text)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text("\(PeriodLabel.range(start: start, end: period.endDate, today: today)) · \(PeriodLabel.relative(start: start, end: period.endDate, today: today))")
                                .font(.meta)
                                .foregroundStyle(Palette.textSecondary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .padding(.top, 12)
        }
    }

    // MARK: Calcul

    /// Morceau d'une période dans une semaine : colonnes de 0 (lundi) à 6.
    struct Bar {
        let task: TaskItem
        let first: Int
        let last: Int
        let startsHere: Bool
        let endsHere: Bool
        let week: [DayKey]

        func covers(_ day: DayKey) -> Bool {
            guard let index = week.firstIndex(of: day) else { return false }
            return first <= index && index <= last
        }
    }

    /// Périodes de la semaine rangées en lignes sans chevauchement, la plus ancienne en haut.
    static func lanes(for periods: [TaskItem], in week: [DayKey]) -> [[Bar]] {
        guard let weekStart = week.first, let weekEnd = week.last else { return [] }
        var lanes: [[Bar]] = []
        for period in periods where period.overlaps(from: weekStart, through: weekEnd) {
            guard let start = period.startDate, let end = period.periodEnd else { continue }
            let first = week.firstIndex(of: max(start, weekStart)) ?? 0
            let last = week.firstIndex(of: min(end, weekEnd)) ?? 6
            let bar = Bar(task: period, first: first, last: last, startsHere: start >= weekStart,
                          endsHere: end <= weekEnd, week: week)
            if let lane = lanes.firstIndex(where: { $0.allSatisfy { $0.last < first || $0.first > last } }) {
                lanes[lane].append(bar)
            } else {
                lanes.append([bar])
            }
        }
        return lanes
    }

    /// Semaines (lundi → dimanche) qui couvrent le mois.
    static func weeks(of monthStart: DayKey) -> [[DayKey]] {
        guard var weekStart = DayKeys.startOfWeek(containing: monthStart) else { return [] }
        let month = monthStart.prefix(7)
        var weeks: [[DayKey]] = []
        while weeks.count < 6 {
            let week = (0..<7).compactMap { DayKeys.adding($0, to: weekStart) }
            guard week.contains(where: { $0.prefix(7) == month }) else { break }
            weeks.append(week)
            guard let next = DayKeys.adding(7, to: weekStart) else { break }
            weekStart = next
        }
        return weeks
    }

    /// Premier jour du mois qui contient `day`.
    static func startOfMonth(containing day: DayKey) -> DayKey {
        String(day.prefix(8)) + "01"
    }

    private func shift(_ months: Int) {
        guard let date = DayKeys.date(from: monthStart),
              let moved = Calendar.current.date(byAdding: .month, value: months, to: date) else { return }
        withAnimation(.easeInOut(duration: 0.2)) { monthStart = Self.startOfMonth(containing: DayKeys.key(for: moved)) }
    }

    private func label(date: Date, isToday: Bool, total: Minutes, periods: [String]) -> String {
        var parts = [date.formatted(.dateTime.weekday(.wide).day().month(.wide))]
        if isToday { parts.append("aujourd'hui") }
        if total > 0 { parts.append("\(TimeText.duration(total)) planifiées") }
        parts.append(contentsOf: periods)
        return parts.joined(separator: ", ")
    }
}
