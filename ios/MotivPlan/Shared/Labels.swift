import CoreModels
import SwiftUI
import TimelineEngine

extension TaskCategory {
    var label: String {
        switch self {
        case .quotidienne: "Quotidienne"
        case .courte: "Courte"
        case .moyenne: "Moyenne"
        case .longue: "Longue"
        case .pro: "Pro"
        }
    }
}

extension Importance {
    var label: String {
        switch self {
        case .basse: "Basse"
        case .normale: "Normale"
        case .haute: "Haute"
        }
    }
}

extension Color {
    /// Signal sobre des retards : ambre doux, jamais rouge (principe 2).
    static let gentleWarning = Color(red: 0.84, green: 0.62, blue: 0.24)
}

enum DayLabel {
    /// « Aujourd'hui », « Demain », « Hier », sinon « mar. 20 oct. ».
    static func text(for day: DayKey, today: DayKey) -> String {
        if day == today { return "Aujourd'hui" }
        if day == DayKeys.adding(1, to: today) { return "Demain" }
        if day == DayKeys.adding(-1, to: today) { return "Hier" }
        guard let date = DayKeys.date(from: day) else { return day }
        let sameYear = day.prefix(4) == today.prefix(4)
        return sameYear
            ? date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
            : date.formatted(.dateTime.day().month(.abbreviated).year())
    }
}
