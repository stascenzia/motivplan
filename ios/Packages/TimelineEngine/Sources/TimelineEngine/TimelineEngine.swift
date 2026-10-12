/// Heures en minutes depuis minuit, dates-jour en clés `yyyy-MM-dd` (ADR-005).
/// Aucun `Date` dans ce module : ni fuseau, ni changement d'heure.
public typealias Minutes = Int
public typealias DayKey = String

public enum TimelineEngine {
    /// Heure de départ du jour par défaut : 09:00.
    public static let defaultDayStart: Minutes = 9 * 60
}
