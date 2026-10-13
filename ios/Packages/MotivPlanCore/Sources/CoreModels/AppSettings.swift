import Foundation
import TimelineEngine

/// Réglages de l'utilisateur, dans les UserDefaults de l'App Group. L'écran de réglages arrive au lot 3.
public struct AppSettings: Sendable, Equatable {
    public var dayStart: Minutes
    public var durations: [TaskCategory: Minutes]

    public init(dayStart: Minutes = TimelineEngine.defaultDayStart,
                durations: [TaskCategory: Minutes] = Durations.initialDefaults) {
        self.dayStart = dayStart
        self.durations = durations
    }

    private static let dayStartKey = "settings.dayStart"
    private static func durationKey(_ category: TaskCategory) -> String { "settings.duration.\(category.rawValue)" }

    public static func load(from defaults: UserDefaults = AppGroup.defaults) -> AppSettings {
        var settings = AppSettings()
        if let start = defaults.object(forKey: dayStartKey) as? Int {
            settings.dayStart = start
        }
        for category in TaskCategory.allCases {
            if let minutes = defaults.object(forKey: durationKey(category)) as? Int {
                settings.durations[category] = max(minutes, Durations.minimum)
            }
        }
        return settings
    }

    public func save(to defaults: UserDefaults = AppGroup.defaults) {
        defaults.set(dayStart, forKey: Self.dayStartKey)
        for (category, minutes) in durations {
            defaults.set(minutes, forKey: Self.durationKey(category))
        }
    }
}
