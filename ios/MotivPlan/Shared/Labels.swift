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

    /// Couleur vive de l’étiquette (DesignSystem/Theme.swift). « Urgent » est rose doux, jamais rouge (principe 2).
    var tint: Color { TagColors.of(self).vivid }
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
    static let gentleWarning = Palette.warning
}

extension SectionKind {
    var label: String {
        switch self {
        case .tasks: "À faire"
        case .memory: "Mémoire avec avis"
        case .checklist: "Liste à cocher"
        case .periods: "Périodes"
        }
    }

    /// Titre de la feuille de création.
    var newTitle: String {
        switch self {
        case .tasks: "Nouvelle tâche"
        case .memory: "Nouvelle envie"
        case .checklist: "Nouvel article"
        case .periods: "Nouvelle période"
        }
    }

    /// Invite du champ titre.
    var titlePrompt: String {
        switch self {
        case .tasks: "Que dois-tu faire ?"
        case .memory: "Un film, une recette…"
        case .checklist: "Un article…"
        case .periods: "Lisbonne, vacances de Noël…"
        }
    }

    var explanation: String {
        switch self {
        case .tasks: "Des tâches à trier et à poser dans ta journée. Elle vit dans la boîte de réception."
        case .memory: "Des envies (films, recettes…) : planifie-les si tu veux, puis donne ton avis. Elle vit dans la Mémoire."
        case .checklist: "Une liste à cocher, comme les courses : coche en magasin, puis vide les cochés. Elle vit dans la Mémoire."
        case .periods: "Des périodes datées, comme un voyage : jamais dans la journée, en bandeau dans le calendrier. Elle vit dans la Mémoire."
        }
    }
}

extension SectionTemplate {
    var label: String {
        switch self {
        case .courses: "Courses"
        case .film: "Films et séries"
        case .recette: "Recettes"
        case .voyage: "Voyages"
        case .liste: "Liste simple"
        }
    }

    var symbol: String {
        switch self {
        case .courses: "cart"
        case .film: "film"
        case .recette: "fork.knife"
        case .voyage: "airplane"
        case .liste: "list.bullet"
        }
    }

    var explanation: String {
        switch self {
        case .courses: "Une liste à cocher : coche en magasin, vide les cochés, ou copie la liste pour Rappels."
        case .film: "Films et séries à voir, avec ton résumé, le genre et la plateforme. Une fois vus, ton avis."
        case .recette: "Recettes à essayer, avec les ingrédients et les étapes. Une fois faites, ton avis et des photos."
        case .voyage: "Voyages et vacances : lieu et dates, en bandeau dans le calendrier. Après, ton avis et des photos."
        case .liste: "Une liste d'idées : un titre et une note, rien de plus."
        }
    }

    /// Titre de la feuille de création.
    var newTitle: String {
        switch self {
        case .courses: "Nouvel article"
        case .film: "Nouveau film ou série"
        case .recette: "Nouvelle recette"
        case .voyage: "Nouveau voyage"
        case .liste: "Nouvelle idée"
        }
    }

    /// Invite du champ titre.
    var titlePrompt: String {
        switch self {
        case .courses: "Un article…"
        case .film: "Dune, The Bear…"
        case .recette: "Curry de lentilles…"
        case .voyage: "Lisbonne, vacances de Noël…"
        case .liste: "Une idée…"
        }
    }

    /// Champs propres au modèle, dans l'ordre d'affichage. Les clés sont stockées (`fieldsRaw`).
    var fields: [TemplateField] {
        switch self {
        case .film:
            [
                TemplateField(key: "format", label: "Format", style: .choice(["Film", "Série"])),
                TemplateField(key: "genre", label: "Genre", style: .choice([
                    "Action", "Animation", "Aventure", "Comédie", "Documentaire", "Drame",
                    "Horreur", "Policier", "Romance", "Science-fiction", "Thriller",
                ])),
                TemplateField(key: "platform", label: "Plateforme", style: .choice([
                    "Netflix", "Prime Video", "Disney+", "Canal+", "Apple TV+", "Max", "Cinéma",
                ])),
                TemplateField(key: "summary", label: "Résumé", style: .multiline("De quoi ça parle, en quelques mots")),
            ]
        case .recette:
            [
                TemplateField(key: "servings", label: "Couverts", style: .number("Pour combien de personnes")),
                TemplateField(key: "ingredients", label: "Ingrédients", style: .multiline("Un ingrédient par ligne")),
                TemplateField(key: "steps", label: "Étapes", style: .multiline("Une étape par ligne")),
                TemplateField(key: "source", label: "Source", style: .text("Lien ou provenance de la recette")),
            ]
        case .voyage:
            [TemplateField(key: "place", label: "Lieu", style: .text("Ville, pays…"))]
        case .courses, .liste:
            []
        }
    }
}

/// Champ d'un modèle de section : texte court, texte long, ou choix parmi des valeurs (une valeur
/// libre reste possible).
struct TemplateField: Identifiable, Hashable {
    enum Style: Hashable {
        case text(String)
        case multiline(String)
        case choice([String])
        /// Nombre entier (couverts d'une recette).
        case number(String)
    }

    let key: String
    let label: String
    let style: Style

    var id: String { key }
}

enum TemplateFields {
    /// Clés résumées sur une ligne, dans cet ordre : « Série · Drame · Netflix », « Lisbonne ».
    private static let summaryKeys = ["format", "genre", "platform", "place"]

    static func summary(of task: TaskItem) -> String? {
        let fields = task.fields
        let parts = summaryKeys.compactMap { fields[$0] }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

enum SubtaskLabel {
    /// « 2/5 étapes », `nil` sans sous-tâches.
    static func progress(_ subtasks: [Subtask]) -> String? {
        guard !subtasks.isEmpty else { return nil }
        return "\(subtasks.filter(\.isDone).count)/\(subtasks.count) étapes"
    }
}

/// Dates d'une période : « 20 – 24 nov. », « dans 3 semaines ».
enum PeriodLabel {
    /// « ven. 20 nov. », « 20 – 24 nov. », « 28 nov. – 3 déc. », année ajoutée hors de l'année en cours.
    static func range(start: DayKey, end: DayKey?, today: DayKey) -> String {
        let end = end ?? start
        guard let first = DayKeys.date(from: start), let last = DayKeys.date(from: end) else { return start }
        let sameYear = start.prefix(4) == today.prefix(4) && end.prefix(4) == today.prefix(4)
        if start == end {
            return sameYear
                ? first.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
                : first.formatted(.dateTime.day().month(.abbreviated).year())
        }
        let lastText = sameYear
            ? last.formatted(.dateTime.day().month(.abbreviated))
            : last.formatted(.dateTime.day().month(.abbreviated).year())
        let sameMonth = start.prefix(7) == end.prefix(7)
        let firstText = sameMonth ? first.formatted(.dateTime.day()) : first.formatted(.dateTime.day().month(.abbreviated))
        return "\(firstText) – \(lastText)"
    }

    /// « demain », « dans 5 jours », « dans 3 semaines », « dans 2 mois », « en cours », « passé ».
    static func relative(start: DayKey, end: DayKey?, today: DayKey) -> String {
        let end = end ?? start
        if end < today { return "passé" }
        if start <= today { return start == end ? "aujourd'hui" : "en cours" }
        let days = daysBetween(today, start)
        switch days {
        case 1: return "demain"
        case ..<14: return "dans \(days) jours"
        case ..<60:
            let weeks = Int((Double(days) / 7).rounded())
            return "dans \(weeks) semaines"
        default:
            let months = Int((Double(days) / 30.4).rounded())
            return "dans \(months) mois"
        }
    }

    /// « 20 – 24 nov. · dans 3 semaines »
    static func summary(start: DayKey, end: DayKey?, today: DayKey) -> String {
        range(start: start, end: end, today: today) + " · " + relative(start: start, end: end, today: today)
    }

    static func daysBetween(_ from: DayKey, _ to: DayKey) -> Int {
        guard let a = DayKeys.date(from: from), let b = DayKeys.date(from: to) else { return 0 }
        return Calendar.current.dateComponents([.day], from: a, to: b).day ?? 0
    }
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
