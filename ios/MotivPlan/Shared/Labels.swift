import CoreModels
import SwiftUI
import TimelineEngine

extension TaskTag {
    var label: String {
        switch self {
        case .urgent: "Urgent"
        case .travail: "Travail"
        case .medium: "Medium"
        case .detente: "Détente"
        }
    }

    var symbol: String {
        switch self {
        case .urgent: "bolt"
        case .travail: "briefcase"
        case .medium: "circle.lefthalf.filled"
        case .detente: "leaf"
        }
    }

    /// Teinte douce des bulles. « Urgent » reste ambre, jamais rouge (principe 2).
    var tint: Color {
        switch self {
        case .urgent: .gentleWarning
        case .travail: .purple
        case .medium: .blue
        case .detente: .mint
        }
    }
}

extension Review {
    var label: String {
        switch self {
        case .aime: "Aimé"
        case .bof: "Bof"
        case .pasAime: "Pas aimé"
        }
    }

    var symbol: String {
        switch self {
        case .aime: "hand.thumbsup"
        case .bof: "hand.raised"
        case .pasAime: "hand.thumbsdown"
        }
    }
}

extension SectionRepeat {
    var label: String {
        switch self {
        case .none: "Ponctuelle"
        case .daily: "Chaque jour"
        case .permanent: "Toujours disponible"
        }
    }

    var explanation: String {
        switch self {
        case .none: "Une fois faite, la tâche est terminée."
        case .daily: "Posée seule dans la journée chaque matin, cochée ou non la veille."
        case .permanent: "Cochée, elle reste dans la boîte avec la date de la dernière fois."
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

    /// « aujourd'hui », « hier », « il y a 4 jours », sinon la date.
    static func since(_ date: Date, today: DayKey) -> String {
        let day = DayKeys.key(for: date)
        if day == today { return "aujourd'hui" }
        if day == DayKeys.adding(-1, to: today) { return "hier" }
        for days in 2...6 where day == DayKeys.adding(-days, to: today) {
            return "il y a \(days) jours"
        }
        return "le " + date.formatted(.dateTime.day().month(.abbreviated))
    }
}
