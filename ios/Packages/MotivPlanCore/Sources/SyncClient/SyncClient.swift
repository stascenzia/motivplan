import Foundation

// Client de synchronisation (lot 8, ADR-009) : drapeau `needsSync`, dernière écriture gagnante,
// curseur serveur. Format JSON aligné sur `backend/app/schemas.py` (clés snake_case).

/// Tâche au format de l'API.
public struct TaskDTO: Codable, Sendable, Equatable {
    public var id: UUID
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?
    public var title: String
    public var notes: String?
    public var sectionId: UUID?
    public var tag: String?
    /// `yyyy-MM-dd`
    public var dueDate: String?
    public var durationMin: Int?
    public var status: String
    /// `yyyy-MM-dd`
    public var scheduledDate: String?
    public var orderIndex: Int?
    public var isAnchored: Bool
    /// `HH:MM:SS`
    public var anchorTime: String?
    public var completedAt: Date?
    public var postponeCount: Int
    public var source: String
    public var review: String?
    public var reviewNote: String?
    /// Présent seulement dans les réponses.
    public var serverUpdatedAt: Date?
}

/// Section au format de l'API.
public struct SectionDTO: Codable, Sendable, Equatable {
    public var id: UUID
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?
    public var name: String
    public var symbol: String
    public var sortIndex: Int
    public var defaultDuration: Int?
    public var isPlannable: Bool
    public var keepsMemory: Bool
    public var `repeat`: String
    public var serverUpdatedAt: Date?
}

/// Session de travail au format de l'API (sans interface avant la v2).
public struct SessionDTO: Codable, Sendable, Equatable {
    public var id: UUID
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?
    public var taskId: UUID
    public var scheduledDate: String
    public var orderIndex: Int
    public var durationMin: Int
    public var completedAt: Date?
    public var serverUpdatedAt: Date?
}

public struct SyncRequestDTO: Codable, Sendable, Equatable {
    public var since: Date?
    public var tasks: [TaskDTO]
    public var sections: [SectionDTO]
    public var sessions: [SessionDTO]

    public init(since: Date?, tasks: [TaskDTO], sections: [SectionDTO], sessions: [SessionDTO]) {
        self.since = since
        self.tasks = tasks
        self.sections = sections
        self.sessions = sessions
    }
}

public struct SyncResponseDTO: Codable, Sendable, Equatable {
    public var serverTime: Date
    public var tasks: [TaskDTO]
    public var sections: [SectionDTO]
    public var sessions: [SessionDTO]

    public init(serverTime: Date, tasks: [TaskDTO] = [], sections: [SectionDTO] = [], sessions: [SessionDTO] = []) {
        self.serverTime = serverTime
        self.tasks = tasks
        self.sections = sections
        self.sessions = sessions
    }
}

/// Encodage commun : clés snake_case, dates ISO 8601 en UTC avec millisecondes.
public enum SyncCoding {
    public static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(format(date))
        }
        return encoder
    }

    public static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            guard let date = parse(text) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Date ISO 8601 invalide : \(text)")
            }
            return date
        }
        return decoder
    }

    public static func format(_ date: Date) -> String {
        date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true))
    }

    /// Accepte les secondes fractionnaires (millisecondes ou microsecondes) et les décalages horaires.
    public static func parse(_ text: String) -> Date? {
        if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(text) { return date }
        if let date = try? Date.ISO8601FormatStyle().parse(text) { return date }
        // Python émet jusqu'à 6 décimales : on ramène à 3 avant de réessayer.
        let trimmed = text.replacing(/(\.\d{3})\d+/) { $0.output.1 }
        return try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(String(trimmed))
    }

    /// Minutes depuis minuit → `HH:MM:00`.
    public static func time(fromMinutes minutes: Int) -> String {
        String(format: "%02d:%02d:00", minutes / 60, minutes % 60)
    }

    /// `HH:MM[:SS[.ffffff]]` → minutes depuis minuit.
    public static func minutes(fromTime text: String) -> Int? {
        let parts = text.split(separator: ":").prefix(2).compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        return parts[0] * 60 + parts[1]
    }
}
