import Foundation

public enum Durations {
    public static let minimum: Minutes = 5
    public static let fallback: Minutes = 30

    /// Durée au dépôt dans la journée : celle de la tâche, sinon la suggestion (durée par défaut de
    /// sa section), sinon 30 min. Jamais sous le minimum.
    public static func defaultDuration(existing: Minutes?, suggested: Minutes?) -> Minutes {
        max(existing ?? suggested ?? fallback, minimum)
    }
}
