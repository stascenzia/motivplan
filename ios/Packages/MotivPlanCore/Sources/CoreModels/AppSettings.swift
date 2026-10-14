import Foundation
import TimelineEngine

/// Réglages de l'utilisateur, dans les UserDefaults de l'App Group.
/// Les durées par défaut vivent sur les sections (ADR-014).
public struct AppSettings: Sendable, Equatable {
    public var dayStart: Minutes

    public init(dayStart: Minutes = TimelineEngine.defaultDayStart) {
        self.dayStart = dayStart
    }

    private static let dayStartKey = "settings.dayStart"

    public static func load(from defaults: UserDefaults = AppGroup.defaults) -> AppSettings {
        var settings = AppSettings()
        if let start = defaults.object(forKey: dayStartKey) as? Int {
            settings.dayStart = start
        }
        return settings
    }

    public func save(to defaults: UserDefaults = AppGroup.defaults) {
        defaults.set(dayStart, forKey: Self.dayStartKey)
    }
}
