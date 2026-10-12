import Foundation

/// Catégories du cahier (§2.1). Des noms, pas des durées : elles ne fournissent qu'une suggestion.
public enum TaskCategory: String, Sendable, Hashable, CaseIterable, Codable {
    case quotidienne, courte, moyenne, longue, pro
}

public enum Durations {
    public static let minimum: Minutes = 5
    public static let fallback: Minutes = 30
    /// Valeurs initiales des réglages, à calibrer à l'usage.
    public static let initialDefaults: [TaskCategory: Minutes] = [
        .quotidienne: 15, .courte: 15, .moyenne: 45, .longue: 90, .pro: 60,
    ]

    /// Durée au drop depuis le tiroir : durée déjà présente sur la tâche, sinon celle de sa catégorie,
    /// sinon 30 min. Jamais sous le minimum.
    public static func defaultDuration(existing: Minutes?, category: TaskCategory?,
                                       defaults: [TaskCategory: Minutes] = initialDefaults) -> Minutes {
        let candidate = existing ?? category.flatMap { defaults[$0] } ?? fallback
        return max(candidate, minimum)
    }
}
