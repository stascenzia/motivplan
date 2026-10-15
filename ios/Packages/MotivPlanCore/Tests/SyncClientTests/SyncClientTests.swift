import CoreModels
import Foundation
import SwiftData
import Testing
@testable import SyncClient

/// Serveur factice : garde la dernière requête et renvoie une réponse préparée.
final class FakeTransport: SyncTransport, @unchecked Sendable {
    var response: SyncResponseDTO
    var lastRequest: SyncRequestDTO?
    var onSend: (@MainActor @Sendable () -> Void)?

    init(response: SyncResponseDTO) {
        self.response = response
    }

    func send(_ request: SyncRequestDTO) async throws -> SyncResponseDTO {
        lastRequest = request
        if let onSend { await onSend() }
        return response
    }
}

@Suite("Format de l'API")
struct CodingTests {
    @Test("Clés snake_case, dates ISO 8601, heure d'ancre en HH:MM:SS")
    func encodesLikeTheBackend() throws {
        let date = Date(timeIntervalSince1970: 1_791_878_400)
        let task = TaskDTO(
            id: UUID(), createdAt: date, updatedAt: date, deletedAt: nil, title: "Dentiste", notes: nil,
            sectionId: UUID(), tag: "urgent", dueDate: "2026-10-13", durationMin: 30, status: "scheduled",
            scheduledDate: "2026-10-13", orderIndex: 1024, isAnchored: true,
            anchorTime: SyncCoding.time(fromMinutes: 9 * 60 + 30), completedAt: nil, postponeCount: 0,
            source: "siri", review: nil, reviewNote: nil, serverUpdatedAt: nil)
        let data = try SyncCoding.encoder.encode(SyncRequestDTO(since: nil, tasks: [task], sections: [], sessions: []))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let encoded = try #require((json["tasks"] as? [[String: Any]])?.first)

        #expect(encoded["section_id"] != nil)
        #expect(encoded["is_anchored"] as? Bool == true)
        #expect(encoded["anchor_time"] as? String == "09:30:00")
        #expect(encoded["created_at"] as? String == "2026-10-13T08:00:00.000Z")
        #expect(encoded["server_updated_at"] == nil)
        #expect(encoded["review"] == nil)
    }

    @Test("Lit les dates de Python : microsecondes, Z ou +00:00")
    func parsesPythonDates() {
        let expected = Date(timeIntervalSince1970: 1_791_878_400.123)
        for text in ["2026-10-13T08:00:00.123456Z", "2026-10-13T08:00:00.123Z", "2026-10-13T08:00:00.123+00:00"] {
            let parsed = SyncCoding.parse(text)
            #expect(parsed.map { abs($0.timeIntervalSince(expected)) < 0.001 } == true, "\(text)")
        }
        #expect(SyncCoding.parse("2026-10-13T08:00:00Z") == Date(timeIntervalSince1970: 1_791_878_400))
    }

    @Test("Décode une réponse du serveur")
    func decodesServerResponse() throws {
        let json = """
        {"server_time": "2026-10-13T08:00:00.000001Z",
         "tasks": [{"id": "5E2F1C9A-3C7B-4C55-9D3E-2F3A1B6C7D8E", "created_at": "2026-10-13T08:00:00Z",
                    "updated_at": "2026-10-13T08:00:00Z", "deleted_at": null, "title": "Lessive",
                    "notes": null, "section_id": null, "tag": null, "due_date": null, "duration_min": null,
                    "status": "inbox", "scheduled_date": null, "order_index": null, "is_anchored": false,
                    "anchor_time": null, "completed_at": null, "postpone_count": 0, "source": "manual",
                    "review": null, "review_note": null, "server_updated_at": "2026-10-13T08:00:00Z"}],
         "sections": [], "sessions": []}
        """
        let response = try SyncCoding.decoder.decode(SyncResponseDTO.self, from: Data(json.utf8))
        #expect(response.tasks.first?.title == "Lessive")
        #expect(response.tasks.first?.serverUpdatedAt != nil)
    }

    @Test("Adresse du serveur normalisée")
    func normalizedURL() {
        #expect(SyncSettings.normalizedURL(" api.exemple.fr/ ")?.absoluteString == "https://api.exemple.fr")
        #expect(SyncSettings.normalizedURL("http://192.168.1.10:8000")?.absoluteString == "http://192.168.1.10:8000")
        #expect(SyncSettings.normalizedURL("") == nil)
    }
}

@MainActor
@Suite("Moteur de synchro")
struct SyncEngineTests {
    let container: ModelContainer
    let store: TaskStore
    let defaults: UserDefaults
    let t0 = Date(timeIntervalSince1970: 1_791_878_400)

    init() throws {
        container = try Persistence.makeContainer(inMemory: true)
        let fixed = Date(timeIntervalSince1970: 1_791_878_400)
        store = TaskStore(context: container.mainContext, settings: AppSettings(), now: { fixed })
        let name = "tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
    }

    private func engine(_ transport: FakeTransport) -> SyncEngine {
        SyncEngine(context: container.mainContext, transport: transport, defaults: defaults)
    }

    private func remoteTask(id: UUID = UUID(), title: String, updatedAt: Date) -> TaskDTO {
        TaskDTO(id: id, createdAt: t0, updatedAt: updatedAt, deletedAt: nil, title: title, notes: nil,
                sectionId: nil, tag: nil, dueDate: nil, durationMin: nil, status: "inbox", scheduledDate: nil,
                orderIndex: nil, isAnchored: false, anchorTime: nil, completedAt: nil, postponeCount: 0,
                source: "manual", review: nil, reviewNote: nil, serverUpdatedAt: updatedAt)
    }

    @Test("Envoie les enregistrements marqués, retire le drapeau, garde le curseur")
    func sendsAndClearsFlags() async throws {
        let task = try store.capture("Courrier", source: .manual)
        let section = try store.createSection(name: "Films", isPlannable: false, keepsMemory: true)
        let transport = FakeTransport(response: SyncResponseDTO(serverTime: t0.addingTimeInterval(60)))

        let summary = try await engine(transport).sync()

        #expect(summary.sent == 2)
        #expect(transport.lastRequest?.tasks.map(\.id) == [task.id])
        #expect(transport.lastRequest?.sections.map(\.id) == [section.id])
        #expect(transport.lastRequest?.since == nil)
        #expect(!task.needsSync)
        #expect(!section.needsSync)

        // Deuxième passage : rien à envoyer, le curseur est celui du serveur.
        try await engine(transport).sync()
        #expect(transport.lastRequest?.tasks.isEmpty == true)
        #expect(transport.lastRequest?.since == t0.addingTimeInterval(60))
    }

    @Test("Une modification pendant l'envoi garde son drapeau")
    func editDuringSyncStaysFlagged() async throws {
        let task = try store.capture("Courrier", source: .manual)
        let transport = FakeTransport(response: SyncResponseDTO(serverTime: t0))
        // Le moteur garde l'objet ; on le retrouve par son identifiant depuis le serveur factice.
        let container = self.container
        let id = task.id
        transport.onSend = {
            let edited = try? container.mainContext.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == id }))
            edited?.first?.updatedAt = Date(timeIntervalSince1970: 1_791_878_500)
        }

        try await engine(transport).sync()
        #expect(task.needsSync)
    }

    @Test("Applique les nouveautés du serveur, la plus récente gagne")
    func appliesRemoteWithLastWriteWins() async throws {
        let local = try store.capture("Version locale", source: .manual)
        let stale = try store.capture("Locale plus récente", source: .manual)
        stale.updatedAt = t0.addingTimeInterval(600)
        let newID = UUID()
        let transport = FakeTransport(response: SyncResponseDTO(serverTime: t0, tasks: [
            remoteTask(id: local.id, title: "Version serveur", updatedAt: t0.addingTimeInterval(300)),
            remoteTask(id: stale.id, title: "Ancienne version serveur", updatedAt: t0.addingTimeInterval(300)),
            remoteTask(id: newID, title: "Créée ailleurs", updatedAt: t0),
        ]))

        try await engine(transport).sync()

        #expect(local.title == "Version serveur")
        #expect(!local.needsSync)
        #expect(stale.title == "Locale plus récente")
        let created = try container.mainContext.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == newID }))
        #expect(created.first?.title == "Créée ailleurs")
        #expect(created.first?.needsSync == false)
    }

    @Test("Une suppression venue d'ailleurs retire la tâche des listes")
    func remoteTombstone() async throws {
        let task = try store.capture("À supprimer", source: .manual)
        var remote = remoteTask(id: task.id, title: "À supprimer", updatedAt: t0.addingTimeInterval(300))
        remote.deletedAt = t0.addingTimeInterval(300)
        try await engine(FakeTransport(response: SyncResponseDTO(serverTime: t0, tasks: [remote]))).sync()

        #expect(task.deletedAt != nil)
        #expect(try store.inbox().isEmpty)
    }

    @Test("Une ancre distante retrouve son heure en minutes")
    func remoteAnchor() async throws {
        var remote = remoteTask(title: "Réunion", updatedAt: t0)
        remote.status = "scheduled"
        remote.scheduledDate = "2026-10-13"
        remote.orderIndex = 1024
        remote.durationMin = 60
        remote.isAnchored = true
        remote.anchorTime = "14:15:00"
        try await engine(FakeTransport(response: SyncResponseDTO(serverTime: t0, tasks: [remote]))).sync()

        let tasks = try store.tasks(on: "2026-10-13")
        #expect(tasks.first?.anchorTime == 14 * 60 + 15)
        #expect(tasks.first?.isAnchored == true)
    }
}
