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

/// Canal de création d'une tâche.
public enum TaskSource: String, Sendable, Hashable, CaseIterable, Codable {
    case manual, siri, widget
}
