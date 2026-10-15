import CoreModels
import Foundation
import SwiftData

/// Échange avec le serveur, remplaçable dans les tests.
public protocol SyncTransport: Sendable {
    func send(_ request: SyncRequestDTO) async throws -> SyncResponseDTO
}

public struct SyncSummary: Sendable, Equatable {
    public let sent: Int
    public let received: Int
}

/// Un aller-retour de synchronisation (ADR-009).
///
/// 1. Envoie tout ce qui porte `needsSync`.
/// 2. Retire le drapeau des enregistrements qui n'ont pas changé pendant l'envoi.
/// 3. Applique ce que renvoie le serveur, si c'est plus récent que la version locale.
/// 4. Garde `server_time` comme prochain `since`.
@MainActor
public final class SyncEngine {
    public static let sinceKey = "sync.since"

    private let context: ModelContext
    private let transport: any SyncTransport
    private let defaults: UserDefaults

    public init(context: ModelContext, transport: any SyncTransport, defaults: UserDefaults = AppGroup.defaults) {
        self.context = context
        self.transport = transport
        self.defaults = defaults
    }

    @discardableResult
    public func sync() async throws -> SyncSummary {
        let tasks = try context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.needsSync }))
        let sections = try context.fetch(FetchDescriptor<TaskSection>(predicate: #Predicate { $0.needsSync }))
        let sessions = try context.fetch(FetchDescriptor<WorkSession>(predicate: #Predicate { $0.needsSync }))

        // Instantané : une modification faite pendant l'envoi garde son drapeau pour le prochain passage.
        let sentTasks = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0.updatedAt) })
        let sentSections = Dictionary(uniqueKeysWithValues: sections.map { ($0.id, $0.updatedAt) })
        let sentSessions = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0.updatedAt) })

        let request = SyncRequestDTO(
            since: defaults.string(forKey: Self.sinceKey).flatMap(SyncCoding.parse),
            tasks: tasks.map(\.dto), sections: sections.map(\.dto), sessions: sessions.map(\.dto))
        let response = try await transport.send(request)

        for task in tasks where task.updatedAt == sentTasks[task.id] { task.needsSync = false }
        for section in sections where section.updatedAt == sentSections[section.id] { section.needsSync = false }
        for session in sessions where session.updatedAt == sentSessions[session.id] { session.needsSync = false }

        try applyRemote(response)
        if context.hasChanges {
            try context.save()
        }
        defaults.set(SyncCoding.format(response.serverTime), forKey: Self.sinceKey)
        return SyncSummary(sent: request.tasks.count + request.sections.count + request.sessions.count,
                           received: response.tasks.count + response.sections.count + response.sessions.count)
    }

    /// Dernière écriture gagnante côté client : une version distante ne remplace la locale
    /// que si elle est strictement plus récente.
    private func applyRemote(_ response: SyncResponseDTO) throws {
        let sectionIds = response.sections.map(\.id)
        let localSections = Dictionary(uniqueKeysWithValues: try context.fetch(
            FetchDescriptor<TaskSection>(predicate: #Predicate { sectionIds.contains($0.id) })).map { ($0.id, $0) })
        for remote in response.sections {
            if let local = localSections[remote.id] {
                if remote.updatedAt > local.updatedAt { local.apply(remote) }
            } else {
                context.insert(TaskSection.make(from: remote))
            }
        }

        let taskIds = response.tasks.map(\.id)
        let localTasks = Dictionary(uniqueKeysWithValues: try context.fetch(
            FetchDescriptor<TaskItem>(predicate: #Predicate { taskIds.contains($0.id) })).map { ($0.id, $0) })
        for remote in response.tasks {
            if let local = localTasks[remote.id] {
                if remote.updatedAt > local.updatedAt { local.apply(remote) }
            } else {
                context.insert(TaskItem.make(from: remote))
            }
        }

        let sessionIds = response.sessions.map(\.id)
        let localSessions = Dictionary(uniqueKeysWithValues: try context.fetch(
            FetchDescriptor<WorkSession>(predicate: #Predicate { sessionIds.contains($0.id) })).map { ($0.id, $0) })
        for remote in response.sessions {
            if let local = localSessions[remote.id] {
                if remote.updatedAt > local.updatedAt { local.apply(remote) }
            } else {
                context.insert(WorkSession.make(from: remote))
            }
        }
    }
}
