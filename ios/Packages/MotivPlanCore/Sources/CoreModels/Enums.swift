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
    /// Posée seule dans la journée chaque matin.
    case daily
    /// Jamais consommée : cochée, elle reste disponible.
    case permanent
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
    public static func inferred(name: String, isPlannable: Bool, keepsMemory: Bool) -> SectionKind {
        if keepsMemory { return .memory }
        let lowered = name.lowercased()
        if ["voyage", "trip", "vacance", "séjour"].contains(where: { lowered.contains($0) }) { return .periods }
        return isPlannable ? .tasks : .checklist
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

    public var kind: SectionKind {
        switch self {
        case .courses: .checklist
        case .film, .recette, .liste: .memory
        case .voyage: .periods
        }
    }

    /// Terminer un élément ouvre l'avis.
    public var asksReview: Bool {
        switch self {
        case .film, .recette, .voyage: true
        case .courses, .liste: false
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

    public init(id: UUID = UUID(), title: String, isDone: Bool = false) {
        self.id = id
        self.title = title
        self.isDone = isDone
    }
}
