import Foundation
import SwiftData
import Testing
@testable import CoreModels

/// Un store installé en v1 s'ouvre en v2 sans rien perdre (ADR-015).
@MainActor
@Suite("Migration du schéma")
struct MigrationTests {
    @Test("Un store v1 sur disque s'ouvre en v2, données intactes, types déduits")
    func v1StoreOpensInV2() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("migration-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }
        let now = Date(timeIntervalSince1970: 1_791_878_400)
        let filmsId = UUID()
        let taskId = UUID()

        do {
            let schema = Schema(versionedSchema: SchemaV1.self)
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
            let context = container.mainContext
            context.insert(SchemaV1.TaskSection(id: filmsId, name: "Films et séries", symbol: "film", sortIndex: 0,
                                                defaultDuration: nil, isPlannable: false, keepsMemory: true,
                                                repeatRule: .none, now: now))
            context.insert(SchemaV1.TaskSection(name: "Trips", symbol: "airplane", sortIndex: 1024,
                                                defaultDuration: nil, isPlannable: true, keepsMemory: false,
                                                repeatRule: .none, now: now))
            let film = SchemaV1.TaskItem(id: taskId, title: "Dune", source: .siri, now: now)
            film.sectionId = filmsId
            context.insert(film)
            try context.save()
        }

        let schema = Schema(versionedSchema: SchemaV2.self)
        let container = try ModelContainer(for: schema, migrationPlan: MotivPlanMigrationPlan.self,
                                           configurations: [ModelConfiguration(schema: schema, url: url)])
        let context = container.mainContext
        let tasks = try context.fetch(FetchDescriptor<TaskItem>())
        #expect(tasks.map(\.id) == [taskId])
        #expect(tasks.first?.sectionId == filmsId)
        #expect(tasks.first?.source == .siri)
        #expect(tasks.first?.startDate == nil)

        let sections = try context.fetch(TaskSection.orderedDescriptor)
        #expect(sections.map(\.kindRaw) == [nil, nil])
        #expect(sections.map(\.kind) == [.memory, .periods])
    }
}
