import Foundation
import TimelineEngine

// `TaskStatus` et `TaskCategory` viennent de TimelineEngine. Les valeurs brutes sont celles du backend.

public enum Importance: String, Sendable, Hashable, CaseIterable, Codable {
    case basse, normale, haute
}

/// Canal de création d'une tâche.
public enum TaskSource: String, Sendable, Hashable, CaseIterable, Codable {
    case manual, siri, widget
}
