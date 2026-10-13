import Foundation
import SwiftData
import Testing
import TimelineEngine
@testable import CoreModels

@MainActor
@Suite("TaskStore")
struct TaskStoreTests {
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

    @Test("La capture crée une tâche en boîte, titre nettoyé, à synchroniser")
    func capture() throws {
        let task = try store.capture("  Appeler le plombier \n", source: .siri)
        #expect(task.title == "Appeler le plombier")
        #expect(task.status == .inbox)
        #expect(task.source == .siri)
        #expect(task.needsSync)
        #expect(try store.inbox().map(\.id) == [task.id])
    }

    @Test("Un titre vide est refusé")
    func emptyTitle() {
        #expect(throws: TaskStore.StoreError.emptyTitle) { try store.capture("   ", source: .manual) }
    }

    @Test("Planifier pose la tâche en fin de jour avec la durée de sa catégorie")
    func scheduleUsesCategoryDuration() throws {
        let first = try store.capture("Courrier", source: .manual)
        let second = try store.capture("Rapport", source: .manual)
        try store.setCategory(.longue, of: second)

        try store.schedule(first, on: store.today)
        try store.schedule(second, on: store.today)

        #expect(try store.inbox().isEmpty)
        #expect(try store.tasks(on: store.today).map(\.id) == [first.id, second.id])
        #expect(first.durationMin == Durations.fallback)
        #expect(second.durationMin == 90)
        #expect(second.status == .scheduled)
    }

    @Test("Une durée déjà présente est conservée")
    func scheduleKeepsDuration() throws {
        let task = try store.capture("Sport", source: .manual)
        try store.setDuration(50, of: task)
        try store.schedule(task, on: store.tomorrow)
        #expect(task.durationMin == 50)
        #expect(task.scheduledDate == "2026-10-14")
    }

    @Test("« Planifier le… » sur un jour lointain")
    func scheduleFarDay() throws {
        let task = try store.capture("Renouveler le passeport", source: .manual)
        try store.schedule(task, on: "2027-03-02")
        #expect(try store.tasks(on: "2027-03-02").map(\.id) == [task.id])
        #expect(try store.tasks(from: "2027-03-01", through: "2027-03-07").count == 1)
    }

    @Test("Retirer d'un jour remet en boîte et désancre")
    func unschedule() throws {
        let task = try store.capture("Dentiste", source: .manual)
        try store.schedule(task, on: store.today)
        try store.unschedule(task)
        #expect(task.status == .inbox)
        #expect(task.scheduledDate == nil)
        #expect(task.orderIndex == nil)
        #expect(!task.isAnchored)
        #expect(try store.tasks(on: store.today).isEmpty)
    }

    @Test("Supprimer pose un tombstone et retire la tâche des requêtes")
    func deleteIsTombstone() throws {
        let kept = try store.capture("Garder", source: .manual)
        let gone = try store.capture("Jeter", source: .manual)
        try store.schedule(gone, on: store.today)
        try store.delete(gone)

        #expect(gone.deletedAt != nil)
        #expect(try store.inbox().map(\.id) == [kept.id])
        #expect(try store.tasks(on: store.today).isEmpty)
        let all = try container.mainContext.fetch(FetchDescriptor<TaskItem>())
        #expect(all.count == 2)
    }

    @Test("Une durée sous 5 min est refusée")
    func durationMinimum() throws {
        let task = try store.capture("Mail", source: .manual)
        #expect(throws: TaskStore.StoreError.durationTooShort) { try store.setDuration(4, of: task) }
    }

    @Test("Échéances et retard")
    func dueDates() throws {
        let task = try store.capture("Impôts", source: .manual)
        try store.setDueDate(store.endOfThisWeek, of: task)
        #expect(task.dueDate == "2026-10-18")
        #expect(!task.isOverdue(today: store.today))
        try store.setDueDate("2026-10-12", of: task)
        #expect(task.isOverdue(today: store.today))
    }

    private func day(_ titles: [String], minutes: Int = 30) throws -> [TaskItem] {
        try titles.map { title in
            let task = try store.capture(title, source: .manual)
            try store.setDuration(minutes, of: task)
            try store.schedule(task, on: store.today)
            return task
        }
    }

    private func displayed() throws -> [String] {
        let tasks = try store.tasks(on: store.today)
        let byId = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0.title) })
        return store.layout(of: tasks).sequence.compactMap { byId[$0] }
    }

    @Test("Déposer à une position du jour")
    func placeAtPosition() throws {
        _ = try day(["A", "B"])
        let dropped = try store.capture("C", source: .manual)
        try store.place(dropped, on: store.today, at: 1)
        #expect(try displayed() == ["A", "C", "B"])
    }

    @Test("Monter et descendre d'un cran")
    func moveByOne() throws {
        let tasks = try day(["A", "B", "C"])
        try store.move(tasks[2], by: -1)
        #expect(try displayed() == ["A", "C", "B"])
        try store.move(tasks[0], by: 1)
        #expect(try displayed() == ["C", "A", "B"])
    }

    @Test("Ancrer une tâche la place à son heure et pousse les flottantes (T2)")
    func anchorPushesFloats() throws {
        let tasks = try day(["A", "M", "B"], minutes: 30)
        try store.setDuration(90, of: tasks[0])
        try store.setDuration(60, of: tasks[1])
        try store.setAnchor(10 * 60, of: tasks[1])
        // A 09:00–10:30 déborderait sur M 10:00 : poussée entière après M.
        #expect(try displayed() == ["M", "A", "B"])
        let layout = store.layout(of: try store.tasks(on: store.today))
        let a = try #require(layout.placements.first { $0.id == tasks[0].id })
        #expect(a.start == 11 * 60)
        #expect(a.pushedPastAnchor == tasks[1].id)

        try store.setAnchor(nil, of: tasks[1])
        #expect(!tasks[1].isAnchored)
        #expect(tasks[1].anchorTime == nil)
    }

    @Test("Cocher ne décale rien et se défait")
    func toggleDone() throws {
        let tasks = try day(["A", "B"])
        let before = store.layout(of: try store.tasks(on: store.today))
        try store.toggleDone(tasks[0])
        #expect(tasks[0].isDone)
        #expect(tasks[0].completedAt != nil)
        #expect(store.layout(of: try store.tasks(on: store.today)) == before)
        try store.toggleDone(tasks[0])
        #expect(tasks[0].status == .scheduled)
        #expect(tasks[0].completedAt == nil)
    }

    @Test("Une édition sans changement ne touche pas updatedAt")
    func noOpEdit() throws {
        let task = try store.capture("Lire", source: .manual)
        task.needsSync = false
        try store.setTitle("Lire", of: task)
        try store.setCategory(nil, of: task)
        #expect(!task.needsSync)
    }
}
