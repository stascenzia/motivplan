import Foundation
import TimelineEngine

// `TaskStatus` vient de TimelineEngine. Les valeurs brutes sont celles du backend.

/// Étiquette de priorité (ADR-014). L'ordre de déclaration est l'ordre de tri.
public enum TaskTag: String, Sendable, Hashable, CaseIterable, Codable {
    case urgent, travail, medium, detente

    /// 0 pour la plus prioritaire.
    public var rank: Int { Self.allCases.firstIndex(of: self) ?? Self.allCases.count }
}

/// Avis rapide sur un élément de mémoire (film vu, recette mangée).
public enum Review: String, Sendable, Hashable, CaseIterable, Codable {
    case aime
    case bof
    case pasAime = "pas_aime"
}

/// Façon dont les tâches d'une section reviennent (ADR-014).
public enum SectionRepeat: String, Sendable, Hashable, CaseIterable, Codable {
    /// Ponctuelle : faite, elle est terminée.
    case none
    /// Revient chaque jour dans le tiroir, à poser soi-même (ADR-018).
    case daily
    /// Jamais consommée : cochée, elle reste disponible.
    case permanent
}

/// Répétition d'une tâche planifiée (ADR-018) : passé son jour, faite ou non, elle se replanifie
/// seule sur sa prochaine date. Rangée dans les champs de la tâche (`fieldsRaw`, clé `repeat`).
public enum TaskRepeat: String, Sendable, Hashable, CaseIterable, Codable {
    case daily
    /// Du lundi au vendredi.
    case weekdays
    case weekly
    case monthly

    /// Première date de la répétition à partir de `from` (inclus), la série partant de `origin`.
    public func next(after origin: DayKey, onOrAfter from: DayKey, calendar: Calendar = .current) -> DayKey? {
        guard let start = DayKeys.date(from: origin, calendar: calendar),
              let floor = DayKeys.date(from: from, calendar: calendar) else { return nil }
        var candidate = start
        // Au plus un peu plus de deux ans de pas : une tâche oubliée longtemps reprend quand même.
        for step in 1...800 {
            let next: Date?
            switch self {
            case .daily, .weekdays: next = calendar.date(byAdding: .day, value: 1, to: candidate)
            case .weekly: next = calendar.date(byAdding: .day, value: 7, to: candidate)
            case .monthly: next = calendar.date(byAdding: .month, value: step, to: start)
            }
            guard let next else { return nil }
            candidate = next
            if self == .weekdays, calendar.isDateInWeekend(candidate) { continue }
            if candidate >= floor { return DayKeys.key(for: candidate, calendar: calendar) }
        }
        return nil
    }
}

/// Type d'une section, qui décide de son espace (ADR-015) : la to-do (boîte, tiroir, journée) ou
/// la mémoire (films, recettes, courses, voyages).
public enum SectionKind: String, Sendable, Hashable, CaseIterable, Codable {
    /// À faire : boîte de réception, tiroir, journée, avec les règles d'ADR-014.
    case tasks
    /// Mémoire avec avis : films, séries, recettes. Un élément peut être planifié, puis noté.
    case memory
    /// Liste à cocher : courses. On coche en magasin, puis on vide les cochés.
    case checklist
    /// Périodes datées : voyages, vacances. Jamais dans la journée, en bandeau dans le calendrier.
    case periods

    /// Vit dans l'onglet Mémoire plutôt que dans la boîte de réception.
    public var isMemorySpace: Bool { self != .tasks }

    /// Type d'une section créée avant la v2, d'après ses règles et son nom.
    /// Un nom de voyage décide avant les règles : une section « Trips » qui gardait la mémoire reste
    /// une section de périodes (dates, lieu, calendrier).
    public static func inferred(name: String, isPlannable: Bool, keepsMemory: Bool) -> SectionKind {
        if isTripName(name) { return .periods }
        if keepsMemory { return .memory }
        return isPlannable ? .tasks : .checklist
    }

    /// « Voyages », « Trips », « Vacances », « Séjours »…
    public static func isTripName(_ name: String) -> Bool {
        let lowered = name.lowercased()
        return ["voyage", "trip", "vacance", "séjour", "sejour"].contains(where: { lowered.contains($0) })
    }
}

/// Canal de création d'une tâche.
public enum TaskSource: String, Sendable, Hashable, CaseIterable, Codable {
    case manual, siri, widget
}

/// Espace d'une capture sans section (ADR-016) : « À trier » de la boîte de réception ou de la
/// Mémoire. Une entrée rangée prend l'espace de sa section.
public enum TaskSpace: String, Sendable, Hashable, CaseIterable, Codable {
    case tasks
    case memory
}

/// Modèle d'une section de la Mémoire (ADR-016) : ses champs propres, son type, son avis.
/// L'utilisateur crée autant de sections qu'il veut à partir d'un modèle ; un nouveau modèle
/// s'ajoute dans le code.
public enum SectionTemplate: String, Sendable, Hashable, CaseIterable, Codable {
    /// Liste à cocher, copiable pour Rappels.
    case courses
    /// Film ou série : résumé, genre, plateforme.
    case film
    /// Recette : ingrédients et étapes.
    case recette
    /// Voyage : lieu, dates, photos à l'avis.
    case voyage
    /// Liste simple : un titre et une note.
    case liste
    /// Valise d'un voyage : un inventaire par catégorie. Coché à l'aller, décoché au retour ;
    /// « Voyage fini » l'archive.
    case valise

    public var kind: SectionKind {
        switch self {
        case .courses: .checklist
        case .film, .recette, .liste, .valise: .memory
        case .voyage: .periods
        }
    }

    /// Terminer un élément ouvre l'avis.
    public var asksReview: Bool {
        switch self {
        case .film, .recette, .voyage: true
        case .courses, .liste, .valise: false
        }
    }

    /// L'avis accepte des photos, gardées sur l'iPhone.
    public var takesPhotos: Bool {
        self == .voyage || self == .recette
    }

    /// Modèle d'une section d'avant la v3, d'après son type et son nom.
    public static func inferred(kind: SectionKind, name: String) -> SectionTemplate? {
        let lowered = name.lowercased()
        switch kind {
        case .tasks: return nil
        case .checklist: return .courses
        case .periods: return .voyage
        case .memory:
            if ["valise", "bagage"].contains(where: { lowered.contains($0) }) { return .valise }
            if ["recette", "cuisine", "plat"].contains(where: { lowered.contains($0) }) { return .recette }
            if ["film", "série", "serie", "ciné"].contains(where: { lowered.contains($0) }) { return .film }
            return .liste
        }
    }
}

/// Étape d'une tâche découpée (ADR-016). Rangée dans la tâche, synchronisée avec elle.
public struct Subtask: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var title: String
    public var isDone: Bool
    /// Catégorie d'un article de valise (« Vêtements »…) ; `nil` pour une étape de tâche.
    public var category: String?

    public init(id: UUID = UUID(), title: String, isDone: Bool = false, category: String? = nil) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.category = category
    }
}

/// Catégories d'une valise, dans l'ordre d'affichage. Un article sans catégorie connue va dans
/// la dernière.
public enum PackingCategory {
    public static let all = ["Vêtements", "Sac à dos", "Divers"]
    public static var fallback: String { all[all.count - 1] }

    public static func of(_ item: Subtask) -> String {
        guard let category = item.category, all.contains(category) else { return fallback }
        return category
    }
}
