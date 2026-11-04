import Foundation
import TimelineEngine

/// Ce que les widgets d'affichage montrent (lot 14, ADR-016) : deux semaines de journées, déjà
/// calculées, et les périodes. L'app l'écrit dans les UserDefaults de l'App Group ; le widget le
/// lit sans ouvrir le store, qui n'a qu'un écrivain (ADR-006). Sans App Group (installation
/// gratuite qui le retire), le widget ne trouve rien et invite à ouvrir l'app.
public struct WidgetSnapshot: Codable, Sendable, Equatable {
    public struct Item: Codable, Sendable, Equatable {
        public var title: String
        /// Minutes depuis minuit.
        public var start: Minutes
        public var end: Minutes
        public var isDone: Bool
        public var tag: String?

        public init(title: String, start: Minutes, end: Minutes, isDone: Bool, tag: String?) {
            self.title = title
            self.start = start
            self.end = end
            self.isDone = isDone
            self.tag = tag
        }
    }

    public struct Day: Codable, Sendable, Equatable {
        public var key: DayKey
        /// Dans l'ordre de la frise.
        public var items: [Item]

        public init(key: DayKey, items: [Item]) {
            self.key = key
            self.items = items
        }

        public var doneCount: Int { items.filter(\.isDone).count }
        public var plannedMinutes: Minutes { items.reduce(0) { $0 + $1.end - $1.start } }
    }

    public struct Period: Codable, Sendable, Equatable {
        public var title: String
        public var start: DayKey
        public var end: DayKey

        public init(title: String, start: DayKey, end: DayKey) {
            self.title = title
            self.start = start
            self.end = end
        }

        public func covers(_ day: DayKey) -> Bool { start <= day && day <= end }
    }

    public var generatedAt: Date
    public var days: [Day]
    public var periods: [Period]

    public init(generatedAt: Date, days: [Day], periods: [Period]) {
        self.generatedAt = generatedAt
        self.days = days
        self.periods = periods
    }

    public func day(_ key: DayKey) -> Day? {
        days.first { $0.key == key }
    }

    /// La tâche en cours à `minute`, sinon la prochaine non faite. `isCurrent` dit laquelle.
    public static func focus(in day: Day, at minute: Minutes) -> (item: Item, isCurrent: Bool)? {
        if let current = day.items.first(where: { !$0.isDone && $0.start <= minute && minute < $0.end }) {
            return (current, true)
        }
        if let next = day.items.first(where: { !$0.isDone && $0.start > minute }) {
            return (next, false)
        }
        return nil
    }

    // MARK: Stockage

    public static let storageKey = "widget.snapshot"

    public func save(to defaults: UserDefaults = AppGroup.defaults) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    public static func load(from defaults: UserDefaults = AppGroup.defaults) -> WidgetSnapshot? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}

extension TaskStore {
    /// Cette semaine et la suivante, du lundi au dimanche : le widget reste juste après minuit.
    public func widgetSnapshot() throws -> WidgetSnapshot {
        let start = DayKeys.startOfWeek(containing: today) ?? today
        let keys = (0..<14).compactMap { DayKeys.adding($0, to: start) }
        let end = keys.last ?? start
        let byDay = Dictionary(grouping: try tasks(from: start, through: end)) { $0.scheduledDate ?? "" }
        let days = keys.map { key in
            let dayTasks = byDay[key] ?? []
            let byId = Dictionary(uniqueKeysWithValues: dayTasks.map { ($0.id, $0) })
            let items = layout(of: dayTasks).placements.compactMap { placement -> WidgetSnapshot.Item? in
                guard let task = byId[placement.id] else { return nil }
                return WidgetSnapshot.Item(title: task.title, start: placement.start, end: placement.end,
                                           isDone: task.isDone, tag: task.tagRaw)
            }
            return WidgetSnapshot.Day(key: key, items: items)
        }
        let periods = try self.periods(from: start, through: end).compactMap { task -> WidgetSnapshot.Period? in
            guard let first = task.startDate, let last = task.periodEnd else { return nil }
            return WidgetSnapshot.Period(title: task.title, start: first, end: last)
        }
        return WidgetSnapshot(generatedAt: now(), days: days, periods: periods)
    }
}
