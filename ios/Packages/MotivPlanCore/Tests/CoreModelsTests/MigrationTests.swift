import Foundation
import SwiftData
import Testing
@testable import CoreModels

/// Un store installé en v1 ou en v2 s'ouvre dans le schéma courant sans rien perdre (ADR-015, ADR-016).
@MainActor
@Suite("Migration du schéma")
struct MigrationTests {
    private let now = Date(timeIntervalSince1970: 1_791_878_400)

    private func temporaryStore() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("migration-\(UUID().uuidString).store")
    }

    private func openCurrent(at url: URL) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV3.self)
        return try ModelContainer(for: schema, migrationPlan: MotivPlanMigrationPlan.self,
                                  configurations: [ModelConfiguration(schema: schema, url: url)])
    }

    @Test("Un store v1 sur disque s'ouvre en v3, données intactes, types et modèles déduits")
    func v1StoreOpensInCurrent() throws {
        let url = temporaryStore()
        defer { try? FileManager.default.removeItem(at: url) }
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

        // Le conteneur doit vivre aussi longtemps que son contexte.
        let container = try openCurrent(at: url)
        let context = container.mainContext
        let tasks = try context.fetch(FetchDescriptor<TaskItem>())
        #expect(tasks.map(\.id) == [taskId])
        #expect(tasks.first?.sectionId == filmsId)
        #expect(tasks.first?.source == .siri)
        #expect(tasks.first?.startDate == nil)
        #expect(tasks.first?.subtasks.isEmpty == true)

        let sections = try context.fetch(TaskSection.orderedDescriptor)
        #expect(sections.map(\.kindRaw) == [nil, nil])
        #expect(sections.map(\.kind) == [.memory, .periods])
        #expect(sections.map(\.template) == [.film, .voyage])
    }

    @Test("Un store v2 sur disque s'ouvre en v3 : périodes gardées, rien dans les nouveaux champs")
    func v2StoreOpensInCurrent() throws {
        let url = temporaryStore()
        defer { try? FileManager.default.removeItem(at: url) }
        let tripsId = UUID()
        let taskId = UUID()

        do {
            let schema = Schema(versionedSchema: SchemaV2.self)
            let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
            let context = container.mainContext
            context.insert(SchemaV2.TaskSection(id: tripsId, name: "Trips", symbol: "airplane", sortIndex: 0,
                                                defaultDuration: nil, isPlannable: false, keepsMemory: false,
                                                repeatRule: .none, kind: .periods, now: now))
            let trip = SchemaV2.TaskItem(id: taskId, title: "Lisbonne", source: .manual, now: now)
            trip.sectionId = tripsId
            trip.startDate = "2026-11-20"
            trip.endDate = "2026-11-24"
            context.insert(trip)
            try context.save()
        }

        // Le conteneur doit vivre aussi longtemps que son contexte.
        let container = try openCurrent(at: url)
        let context = container.mainContext
        let task = try #require(try context.fetch(FetchDescriptor<TaskItem>()).first)
        #expect(task.id == taskId)
        #expect(task.startDate == "2026-11-20")
        #expect(task.endDate == "2026-11-24")
        #expect(task.spaceRaw == nil)
        #expect(task.fields.isEmpty)
        let section = try #require(try context.fetch(TaskSection.orderedDescriptor).first)
        #expect(section.kind == .periods)
        #expect(section.templateRaw == nil)
        #expect(section.template == .voyage)
    }
}
