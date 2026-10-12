import Foundation

/// Heures en minutes depuis minuit, dates-jour en clés `yyyy-MM-dd` (ADR-005).
/// Aucun `Date` dans ce module : ni fuseau, ni changement d'heure.
public typealias Minutes = Int
public typealias DayKey = String

public enum TimelineEngine {
    /// Heure de départ du jour par défaut : 09:00.
    public static let defaultDayStart: Minutes = 9 * 60
}

/// Une tâche posée sur un jour, réduite à ce dont le calcul a besoin.
public struct TimelineItem: Sendable, Hashable, Identifiable {
    public let id: UUID
    public var orderIndex: Int
    public var durationMin: Minutes
    /// Heure fixe de début si la tâche est ancrée, `nil` si elle est flottante.
    public var anchorStart: Minutes?

    public init(id: UUID, orderIndex: Int, durationMin: Minutes, anchorStart: Minutes? = nil) {
        self.id = id
        self.orderIndex = orderIndex
        self.durationMin = durationMin
        self.anchorStart = anchorStart
    }

    public var isAnchored: Bool { anchorStart != nil }
}
