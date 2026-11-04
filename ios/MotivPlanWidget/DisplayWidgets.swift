import CoreModels
import SwiftUI
import WidgetKit

// Widgets d'affichage (lot 14, ADR-016). Ils lisent l'instantané écrit par l'app dans l'App Group
// (`WidgetSnapshot`), jamais le store. Sans instantané, ils invitent à ouvrir l'app.

struct DisplayEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

/// Heures et jours dans le fuseau de l'iPhone.
private enum WidgetTime {
    static func minute(of date: Date) -> Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    static func clock(_ minutes: Int) -> String {
        String(format: "%02d:%02d", (minutes / 60) % 24, minutes % 60)
    }

    static func date(_ minutes: Int, on day: Date) -> Date {
        Calendar.current.startOfDay(for: day).addingTimeInterval(TimeInterval(minutes * 60))
    }

    static var nextMidnight: Date {
        Calendar.current.startOfDay(for: .now).addingTimeInterval(24 * 3600 + 60)
    }
}

// MARK: Écran verrouillé : la tâche en cours ou la suivante

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> DisplayEntry {
        DisplayEntry(date: .now, snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (DisplayEntry) -> Void) {
        completion(DisplayEntry(date: .now, snapshot: WidgetSnapshot.load()))
    }

    /// Une entrée à chaque début et fin de tâche d'aujourd'hui, puis relecture après minuit.
    func getTimeline(in context: Context, completion: @escaping (Timeline<DisplayEntry>) -> Void) {
        let snapshot = WidgetSnapshot.load()
        let now = Date.now
        var dates = [now]
        if let day = snapshot?.day(DayKeys.key(for: now)) {
            let boundaries = Set(day.items.flatMap { [$0.start, $0.end] })
            dates += boundaries.sorted().map { WidgetTime.date($0, on: now) }.filter { $0 > now }
        }
        let entries = dates.map { DisplayEntry(date: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: .after(WidgetTime.nextMidnight)))
    }
}

struct TodayWidgetView: View {
    let entry: DisplayEntry

    var body: some View {
        if let snapshot = entry.snapshot, let day = snapshot.day(DayKeys.key(for: entry.date)) {
            content(day)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text("MotivPlan")
                    .font(.caption2.weight(.semibold))
                Text("Ouvre l'app pour afficher ta journée")
                    .font(.caption)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func content(_ day: WidgetSnapshot.Day) -> some View {
        let focus = WidgetSnapshot.focus(in: day, at: WidgetTime.minute(of: entry.date))
        let total = day.items.count
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(caption(focus, total: total))
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 2)
                if total > 0 {
                    Text("\(day.doneCount) / \(total)")
                        .font(.caption2.weight(.semibold).monospacedDigit())
                }
            }
            Text(focus?.item.title ?? (total == 0 ? "Rien de prévu" : "Bravo, tout est fait"))
                .font(.headline)
                .lineLimit(1)
            if total > 0 {
                ProgressView(value: Double(day.doneCount), total: Double(total))
                    .tint(.teal)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func caption(_ focus: (item: WidgetSnapshot.Item, isCurrent: Bool)?, total: Int) -> String {
        guard let focus else { return total == 0 ? "Aujourd'hui" : "Journée terminée" }
        return focus.isCurrent
            ? "En cours · jusqu'à \(WidgetTime.clock(focus.item.end))"
            : "Ensuite · \(WidgetTime.clock(focus.item.start))"
    }
}

struct TodayWidget: Widget {
    let kind = AppGroup.todayWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
                .widgetURL(AppGroup.todayURL)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Ma journée")
        .description("La tâche en cours ou la suivante, et ta progression du jour.")
        .supportedFamilies([.accessoryRectangular])
    }
}

// MARK: Grand widget : la semaine

struct WeekProvider: TimelineProvider {
    func placeholder(in context: Context) -> DisplayEntry {
        DisplayEntry(date: .now, snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (DisplayEntry) -> Void) {
        completion(DisplayEntry(date: .now, snapshot: WidgetSnapshot.load()))
    }

    /// L'app recharge le widget quand la semaine change ; sinon, relecture après minuit.
    func getTimeline(in context: Context, completion: @escaping (Timeline<DisplayEntry>) -> Void) {
        let entry = DisplayEntry(date: .now, snapshot: WidgetSnapshot.load())
        completion(Timeline(entries: [entry], policy: .after(WidgetTime.nextMidnight)))
    }
}

struct WeekWidgetView: View {
    let entry: DisplayEntry

    var body: some View {
        let today = DayKeys.key(for: entry.date)
        let start = DayKeys.startOfWeek(containing: today) ?? today
        let keys = (0..<7).compactMap { DayKeys.adding($0, to: start) }
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Cette semaine")
                    .font(.headline)
                Spacer()
                if let first = DayKeys.date(from: start) {
                    Text("du \(first.formatted(.dateTime.day().month(.abbreviated)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let snapshot = entry.snapshot {
                ForEach(keys, id: \.self) { key in
                    dayRow(key, today: today, snapshot: snapshot)
                    if key != keys.last { Divider() }
                }
            } else {
                Spacer()
                Text("Ouvre MotivPlan pour afficher ta semaine.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    private func dayRow(_ key: String, today: String, snapshot: WidgetSnapshot) -> some View {
        let day = snapshot.day(key)
        let items = day?.items ?? []
        let periods = snapshot.periods.filter { $0.covers(key) }
        let isToday = key == today
        let date = DayKeys.date(from: key) ?? entry.date
        return HStack(alignment: .center, spacing: 8) {
            VStack(spacing: 0) {
                Text(date.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.caption2)
                    .foregroundStyle(isToday ? Color.teal : Color.secondary)
                Text(date.formatted(.dateTime.day()))
                    .font(.subheadline.weight(isToday ? .heavy : .semibold))
                    .foregroundStyle(isToday ? Color.teal : Color.primary)
            }
            .frame(width: 34)
            VStack(alignment: .leading, spacing: 1) {
                if let period = periods.first {
                    Text(period.title)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(.purple, in: Capsule())
                        .lineLimit(1)
                }
                Text(summary(items))
                    .font(.caption)
                    .foregroundStyle(items.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !items.isEmpty {
                Text("\(items.filter(\.isDone).count)/\(items.count)")
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxHeight: .infinity)
    }

    /// « Rapport · Banque · +2 », ou « Libre ».
    private func summary(_ items: [WidgetSnapshot.Item]) -> String {
        guard !items.isEmpty else { return "Libre" }
        let shown = items.prefix(2).map(\.title)
        let rest = items.count - shown.count
        return (shown + (rest > 0 ? ["+\(rest)"] : [])).joined(separator: " · ")
    }
}

struct WeekWidget: Widget {
    let kind = AppGroup.weekWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeekProvider()) { entry in
            WeekWidgetView(entry: entry)
                .widgetURL(AppGroup.calendarURL)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Ma semaine")
        .description("Les sept jours de la semaine, tes tâches et tes voyages.")
        .supportedFamilies([.systemLarge])
    }
}
