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

    @Test("Planifier pose la tâche en fin de jour avec la durée de sa section")
    func scheduleUsesSectionDuration() throws {
        let first = try store.capture("Courrier", source: .manual)
        let second = try store.capture("Rapport", source: .manual)
        try store.setSection(try store.createSection(name: "Longues", defaultDuration: 90), of: second)

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
        // Séquence normalisée : A suit M dans l'ordre stocké, elle n'est plus « poussée » au calcul.
        #expect(a.start == 11 * 60)
        #expect(a.pushedPastAnchor == nil)

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

    private func volatileDefaults() -> UserDefaults {
        let name = "tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("Report : flottantes d'hier à la suite d'aujourd'hui, ancrée ratée en boîte")
    func rollover() throws {
        let yesterday = "2026-10-12"
        let z = try store.capture("Z", source: .manual)
        try store.schedule(z, on: store.today)
        let done = try store.capture("Faite hier", source: .manual)
        try store.schedule(done, on: yesterday)
        try store.toggleDone(done)
        let x = try store.capture("X", source: .manual)
        try store.schedule(x, on: yesterday)
        let y = try store.capture("Y", source: .manual)
        try store.schedule(y, on: yesterday)
        let meeting = try store.capture("Réunion", source: .manual)
        try store.schedule(meeting, on: yesterday)
        try store.setAnchor(15 * 60, of: meeting)

        let defaults = volatileDefaults()
        #expect(try store.rollover(defaults: defaults) == 3)

        #expect(try displayed() == ["Z", "X", "Y"])
        #expect(x.postponeCount == 1)
        #expect(y.postponeCount == 1)
        #expect(done.scheduledDate == yesterday)
        #expect(meeting.status == .inbox)
        #expect(!meeting.isAnchored)
        #expect(meeting.dueDate == yesterday)
        #expect(meeting.isOverdue(today: store.today))

        // Deuxième ouverture du jour : rien ne bouge.
        #expect(try store.rollover(defaults: defaults) == 0)
        #expect(x.postponeCount == 1)
    }

    @Test("Le report suit une tâche faite aujourd'hui sans la doubler")
    func rolloverAfterDoneToday() throws {
        let doneToday = try store.capture("Faite", source: .manual)
        try store.schedule(doneToday, on: store.today)
        try store.toggleDone(doneToday)
        let late = try store.capture("En retard", source: .manual)
        try store.schedule(late, on: "2026-10-10")

        try store.rollover(defaults: volatileDefaults())
        #expect(try displayed() == ["Faite", "En retard"])
    }

    // MARK: Vue semaine (lot 6)

    @Test("Changer de jour : fin de séquence, ancre gardée et replacée, jour quitté réaligné")
    func moveToAnotherDay() throws {
        let tomorrow = store.tomorrow
        let other = try store.capture("Courrier", source: .manual)
        try store.schedule(other, on: tomorrow)
        let late = try store.capture("Tardive", source: .manual)
        try store.setDuration(60, of: late)
        try store.schedule(late, on: tomorrow)

        let today = try day(["A", "B"])
        try store.setAnchor(9 * 60 + 30, of: today[1])
        try store.schedule(today[1], on: tomorrow)

        // L'ancre de 09:30 se place parmi les tâches de demain : Courrier 09:00, ancre, puis Tardive.
        let tomorrowTasks = try store.tasks(on: tomorrow)
        let byId = Dictionary(uniqueKeysWithValues: tomorrowTasks.map { ($0.id, $0.title) })
        let sequence = store.layout(of: tomorrowTasks).sequence.compactMap { byId[$0] }
        #expect(sequence == ["Courrier", "B", "Tardive"])
        #expect(today[1].isAnchored)
        #expect(today[1].anchorTime == 9 * 60 + 30)
        #expect(try displayed() == ["A"])
    }

    @Test("Semaine : tâches du lundi au dimanche")
    func weekRange() throws {
        let monday = try #require(DayKeys.startOfWeek(containing: store.today))
        let sunday = try #require(DayKeys.endOfWeek(containing: store.today))
        let inside = try store.capture("Dedans", source: .manual)
        try store.schedule(inside, on: sunday)
        let outside = try store.capture("Dehors", source: .manual)
        try store.schedule(outside, on: try #require(DayKeys.adding(1, to: sunday)))
        #expect(try store.tasks(from: monday, through: sunday).map(\.id) == [inside.id])
    }

    // MARK: Sections et mémoire (ADR-014)

    @Test("Les sections fournies sont créées une seule fois")
    func defaultSections() throws {
        let defaults = volatileDefaults()
        try store.ensureDefaultSections(defaults: defaults)
        try store.ensureDefaultSections(defaults: defaults)
        #expect(try store.sections().map(\.name) == SectionPreset.all.map(\.name))
    }

    @Test("Une quotidienne est posée aujourd'hui, puis chaque matin même cochée")
    func dailyTask() throws {
        let daily = try store.createSection(name: "Quotidiennes", defaultDuration: 15, repeatRule: .daily)
        let bed = try store.capture("Faire le lit", source: .manual)
        try store.setSection(daily, of: bed)
        #expect(bed.scheduledDate == store.today)
        #expect(bed.durationMin == 15)

        // La veille, cochée : le lendemain elle revient non cochée, sans compter de report.
        bed.scheduledDate = "2026-10-12"
        try store.toggleDone(bed)
        try store.rollover(defaults: volatileDefaults())
        #expect(bed.scheduledDate == store.today)
        #expect(bed.status == .scheduled)
        #expect(bed.postponeCount == 0)
    }

    @Test("Une permanente cochée depuis la boîte y reste, datée")
    func permanentFromInbox() throws {
        let recurring = try store.createSection(name: "Récurrentes", repeatRule: .permanent)
        let laundry = try store.capture("Lessive", source: .manual)
        try store.setSection(recurring, of: laundry)
        try store.toggleDone(laundry)
        #expect(laundry.status == .inbox)
        #expect(laundry.completedAt != nil)
        #expect(try store.tasks(in: recurring).map(\.id) == [laundry.id])
    }

    @Test("Une permanente cochée dans la journée revient en boîte au report")
    func permanentFromDay() throws {
        let recurring = try store.createSection(name: "Récurrentes", repeatRule: .permanent)
        let trash = try store.capture("Poubelles", source: .manual)
        try store.setSection(recurring, of: trash)
        try store.schedule(trash, on: "2026-10-12")
        try store.toggleDone(trash)
        try store.rollover(defaults: volatileDefaults())
        #expect(trash.status == .inbox)
        #expect(trash.scheduledDate == nil)
        #expect(trash.completedAt != nil)
    }

    @Test("Terminer un film le range en mémoire avec son avis")
    func memory() throws {
        let films = try store.createSection(name: "Films", isPlannable: false, keepsMemory: true)
        let film = try store.capture("Dune", source: .manual)
        try store.setSection(films, of: film)
        try store.complete(film, review: .aime, note: "  Superbe image  ")
        #expect(try store.tasks(in: films).isEmpty)
        #expect(try store.memory(of: films).map(\.id) == [film.id])
        #expect(film.review == .aime)
        #expect(film.reviewNote == "Superbe image")
    }

    @Test("Une section non planifiable retire la tâche de la journée")
    func unplannableSection() throws {
        let series = try store.createSection(name: "Séries", isPlannable: false)
        let task = try store.capture("The Bear", source: .manual)
        try store.schedule(task, on: store.today)
        try store.setSection(series, of: task)
        #expect(task.scheduledDate == nil)
        #expect(task.status == .inbox)
    }

    @Test("Supprimer une section renvoie ses tâches dans « À trier »")
    func deleteSection() throws {
        let section = try store.createSection(name: "Bricolage")
        let task = try store.capture("Fixer l'étagère", source: .manual)
        try store.setSection(section, of: task)
        try store.deleteSection(section)
        #expect(task.sectionId == nil)
        #expect(try store.sections().isEmpty)
        #expect(try store.tasks(in: nil).map(\.id) == [task.id])
    }

    @Test("Réordonner les sections")
    func moveSection() throws {
        let a = try store.createSection(name: "A")
        _ = try store.createSection(name: "B")
        _ = try store.createSection(name: "C")
        try store.moveSection(a, to: 2)
        #expect(try store.sections().map(\.name) == ["B", "C", "A"])
    }

    @Test("Une édition sans changement ne touche pas updatedAt")
    func noOpEdit() throws {
        let task = try store.capture("Lire", source: .manual)
        task.needsSync = false
        try store.setTitle("Lire", of: task)
        try store.setTag(nil, of: task)
        #expect(!task.needsSync)
    }
}
