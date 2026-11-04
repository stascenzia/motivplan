import Foundation
import SwiftData
import Testing
import TimelineEngine
@testable import CoreModels

/// Lots 12 à 14 (ADR-016) : deux « À trier », sous-tâches, modèles de section, instantané des widgets.
@MainActor
@Suite("Capture, sous-tâches et modèles")
struct MemoryTemplateTests {
    let container: ModelContainer
    let store: TaskStore

    init() throws {
        container = try Persistence.makeContainer(inMemory: true)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        // Mardi 13 octobre 2026, 10:00 à Paris.
        let fixed = Date(timeIntervalSince1970: 1_791_878_400)
        store = TaskStore(context: container.mainContext, settings: AppSettings(),
                          calendar: calendar, now: { fixed })
    }

    // MARK: Deux « À trier »

    @Test("Une capture mémoire va dans « À trier » de la Mémoire, pas dans la boîte")
    func memoryCapture() throws {
        let task = try store.capture("Dune", source: .siri)
        let film = try store.capture("Past Lives", source: .siri, space: .memory)
        #expect(task.isUnsortedTask)
        #expect(!task.isUnsortedMemory)
        #expect(film.isUnsortedMemory)
        #expect(!film.isUnsortedTask)
        #expect(film.spaceRaw == "memory")
        #expect(task.spaceRaw == nil)
    }

    @Test("Rangée puis retirée, une entrée revient dans l'« À trier » de sa section")
    func spaceFollowsSection() throws {
        let films = try store.createSection(name: "Films", template: .film)
        let chores = try store.createSection(name: "Maison")
        let task = try store.capture("Dune", source: .widget)

        try store.setSection(films, of: task)
        #expect(task.space == .memory)
        try store.setSection(nil, of: task)
        #expect(task.isUnsortedMemory)

        try store.setSection(chores, of: task)
        #expect(task.space == .tasks)
        try store.deleteSection(chores)
        #expect(task.isUnsortedTask)
    }

    @Test("Changer le type d'une section déplace ses entrées d'espace")
    func kindChangeMovesSpace() throws {
        let section = try store.createSection(name: "Idées")
        let task = try store.capture("Un roman", source: .manual)
        try store.setSection(section, of: task)
        try store.updateSection(section, name: "Idées", symbol: "lightbulb", defaultDuration: nil,
                                isPlannable: false, keepsMemory: false, repeatRule: .none, template: .liste)
        #expect(section.kind == .memory)
        #expect(section.template == .liste)
        #expect(task.space == .memory)
    }

    // MARK: Sous-tâches

    @Test("Découper une tâche : ajouter, cocher, renommer, déplacer, retirer")
    func subtasks() throws {
        let task = try store.create(TaskDraft(title: "Finir l'appli", subtasks: ["Finir les tests", "  ", "Pousser sur git"]))
        #expect(task.subtasks.map(\.title) == ["Finir les tests", "Pousser sur git"])

        let release = try store.addSubtask("Publier", to: task)
        #expect(task.subtasks.count == 3)

        let tests = task.subtasks[0].id
        try store.toggleSubtask(tests, of: task)
        #expect(task.subtasks[0].isDone)
        #expect(!task.isDone)

        try store.renameSubtask(tests, to: "Finir tous les tests", of: task)
        try store.moveSubtask(release.id, to: 0, of: task)
        #expect(task.subtasks.map(\.title) == ["Publier", "Finir tous les tests", "Pousser sur git"])

        try store.deleteSubtask(release.id, of: task)
        try store.deleteSubtask(tests, of: task)
        try store.deleteSubtask(task.subtasks[0].id, of: task)
        #expect(task.subtasks.isEmpty)
        #expect(task.subtasksRaw == nil)
        #expect(task.needsSync)
    }

    @Test("Une sous-tâche sans titre est refusée")
    func emptySubtask() throws {
        let task = try store.capture("Déménager", source: .manual)
        #expect(throws: TaskStore.StoreError.emptyTitle) { try store.addSubtask("  ", to: task) }
    }

    // MARK: Modèles

    @Test("Champs d'un modèle : créés avec l'entrée, modifiés ensuite, vides retirés")
    func fields() throws {
        let films = try store.createSection(name: "Films", template: .film)
        let dune = try store.create(TaskDraft(title: "Dune", sectionId: films.id, space: .memory,
                                              fields: ["genre": "Science-fiction", "platform": " "]))
        #expect(dune.fields == ["genre": "Science-fiction"])

        try store.setField("platform", to: "Netflix", of: dune)
        #expect(dune.field("platform") == "Netflix")
        #expect(dune.fieldsRaw == #"{"genre":"Science-fiction","platform":"Netflix"}"#)

        try store.setField("genre", to: "", of: dune)
        try store.setField("platform", to: nil, of: dune)
        #expect(dune.fieldsRaw == nil)
    }

    @Test("Le modèle décide du type et de l'avis")
    func templateRules() throws {
        let groceries = try store.createSection(name: "Courses", template: .courses)
        let trips = try store.createSection(name: "Voyages", template: .voyage)
        let notes = try store.createSection(name: "Livres à lire", template: .liste)
        let films = try store.createSection(name: "Ciné", template: .film)
        #expect(groceries.kind == .checklist)
        #expect(trips.kind == .periods)
        #expect(notes.kind == .memory)
        #expect(!notes.asksReview)
        #expect(films.asksReview)
        #expect(trips.asksReview)
        #expect(!groceries.asksReview)
        // Une section à faire n'a pas de modèle.
        #expect(try store.createSection(name: "Admin", template: nil).template == nil)
    }

    @Test("Sans modèle stocké, il se déduit du type et du nom")
    func inferredTemplate() {
        #expect(SectionTemplate.inferred(kind: .memory, name: "Recettes de mamie") == .recette)
        #expect(SectionTemplate.inferred(kind: .memory, name: "Films et séries") == .film)
        #expect(SectionTemplate.inferred(kind: .memory, name: "Idées cadeaux") == .liste)
        #expect(SectionTemplate.inferred(kind: .checklist, name: "Pharmacie") == .courses)
        #expect(SectionTemplate.inferred(kind: .periods, name: "Trips") == .voyage)
        #expect(SectionTemplate.inferred(kind: .tasks, name: "Films") == nil)
    }

    @Test("Les sections fournies portent leur modèle")
    func presetTemplates() throws {
        try store.ensureDefaultSections(defaults: UserDefaults(suiteName: "presets.\(UUID().uuidString)")!)
        let templates = Dictionary(uniqueKeysWithValues: try store.sections().map { ($0.name, $0.templateRaw) })
        #expect(templates["Courses"] == "courses")
        #expect(templates["Films et séries"] == "film")
        #expect(templates["Recettes"] == "recette")
        #expect(templates["Voyages"] == "voyage")
        #expect(templates["Ponctuelles"] == .some(nil))
    }

    // MARK: Widgets

    @Test("L'instantané des widgets : deux semaines, la frise calculée, les périodes")
    func widgetSnapshot() throws {
        let report = try store.capture("Rapport", source: .manual)
        try store.setDuration(60, of: report)
        try store.schedule(report, on: store.today)
        let call = try store.capture("Appeler la banque", source: .manual)
        try store.schedule(call, on: store.today)
        try store.toggleDone(call)
        let trips = try store.createSection(name: "Voyages", template: .voyage)
        let lisbon = try store.capture("Lisbonne", source: .manual)
        try store.setSection(trips, of: lisbon)
        try store.setPeriod(start: "2026-10-17", end: "2026-10-20", of: lisbon)

        let snapshot = try store.widgetSnapshot()
        #expect(snapshot.days.count == 14)
        #expect(snapshot.days.first?.key == "2026-10-12")
        let today = try #require(snapshot.day("2026-10-13"))
        #expect(today.items.map(\.title) == ["Rapport", "Appeler la banque"])
        #expect(today.doneCount == 1)
        #expect(today.items[0].start == store.settings.dayStart)
        #expect(today.items[1].start == store.settings.dayStart + 60)
        #expect(snapshot.periods.map(\.title) == ["Lisbonne"])
        #expect(snapshot.periods.first?.covers("2026-10-18") == true)

        // Pendant le rapport, puis après lui : la banque est faite, il n'y a plus rien.
        #expect(WidgetSnapshot.focus(in: today, at: store.settings.dayStart + 10)?.item.title == "Rapport")
        #expect(WidgetSnapshot.focus(in: today, at: store.settings.dayStart + 10)?.isCurrent == true)
        #expect(WidgetSnapshot.focus(in: today, at: store.settings.dayStart - 30)?.isCurrent == false)
        #expect(WidgetSnapshot.focus(in: today, at: store.settings.dayStart + 70) == nil)

        let defaults = try #require(UserDefaults(suiteName: "snapshot.\(UUID().uuidString)"))
        snapshot.save(to: defaults)
        #expect(WidgetSnapshot.load(from: defaults) == snapshot)
    }
}
