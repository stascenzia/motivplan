import Foundation
import TimelineEngine

enum TimeText {
    /// « 09:30 ». Au-delà de minuit, l'heure reboucle : le dépassement est signalé à part.
    static func clock(_ minutes: Minutes) -> String {
        String(format: "%02d:%02d", (minutes / 60) % 24, minutes % 60)
    }

    /// « 45 min », « 1 h », « 1 h 30 ».
    static func duration(_ minutes: Minutes) -> String {
        if minutes < 60 { return "\(minutes) min" }
        let rest = minutes % 60
        return rest == 0 ? "\(minutes / 60) h" : String(format: "%d h %02d", minutes / 60, rest)
    }

    /// Heure ronde suivante, point de départ du réglage d'une ancre (principe 4 : pas de sélecteur).
    static func nextRoundHour(after date: Date = .now, calendar: Calendar = .current) -> Minutes {
        let parts = calendar.dateComponents([.hour], from: date)
        return min(((parts.hour ?? 8) + 1) * 60, 22 * 60)
    }
}
