import Foundation
import Testing
@testable import TimelineEngine

@Suite("Report automatique")
struct RolloverTests {
    let today: DayKey = "2026-10-12"

    @Test("[X, Y] non faits hier + [Z] déjà posé aujourd'hui → [Z, X, Y]")
    func floatsAppendAfterToday() {
        let x = RolloverTask(id: UUID(), status: .scheduled, scheduledDate: "2026-10-11", orderIndex: 1024)
        let y = RolloverTask(id: UUID(), status: .scheduled, scheduledDate: "2026-10-11", orderIndex: 2048)
        let z = RolloverTask(id: UUID(), status: .scheduled, scheduledDate: today, orderIndex: 1024)

        let changed = Rollover.apply(to: [y, z, x], today: today)
        #expect(changed.map(\.id) == [x.id, y.id])
        #expect(changed.allSatisfy { $0.scheduledDate == today && $0.postponeCount == 1 })

        let finalOrder = ([z] + changed).sorted { $0.orderIndex! < $1.orderIndex! }.map(\.id)
        #expect(finalOrder == [z.id, x.id, y.id])
    }

    @Test("Plusieurs jours passés : ordre (jour, orderIndex), +1 une seule fois")
    func multipleDays() {
        let old = RolloverTask(id: UUID(), status: .scheduled, scheduledDate: "2026-10-08", orderIndex: 5000,
                               postponeCount: 2)
        let recent = RolloverTask(id: UUID(), status: .scheduled, scheduledDate: "2026-10-11", orderIndex: 1024)

        let changed = Rollover.apply(to: [recent, old], today: today)
        #expect(changed.map(\.id) == [old.id, recent.id])
        #expect(changed[0].postponeCount == 3)
        #expect(changed[1].postponeCount == 1)
    }

    @Test("Ancrée ratée → boîte de réception, désancrée, échéance = ancien jour")
    func missedAnchorGoesToInbox() {
        let anchored = RolloverTask(id: UUID(), status: .scheduled, scheduledDate: "2026-10-11",
                                    orderIndex: 1024, anchorStart: 14 * 60)
        let changed = Rollover.apply(to: [anchored], today: today)
        #expect(changed.count == 1)
        let moved = changed[0]
        #expect(moved.status == .inbox)
        #expect(moved.scheduledDate == nil)
        #expect(moved.orderIndex == nil)
        #expect(!moved.isAnchored)
        #expect(moved.dueDate == "2026-10-11")
        #expect(moved.postponeCount == 0)
    }

    @Test func missedAnchorKeepsExistingDueDate() {
        let anchored = RolloverTask(id: UUID(), status: .scheduled, scheduledDate: "2026-10-11",
                                    orderIndex: 1024, anchorStart: 600, dueDate: "2026-10-20")
        #expect(Rollover.apply(to: [anchored], today: today).first?.dueDate == "2026-10-20")
    }

    @Test("Tâches faites, en inbox ou futures : intouchées")
    func untouchedTasks() {
        let done = RolloverTask(id: UUID(), status: .done, scheduledDate: "2026-10-11", orderIndex: 1024)
        let inbox = RolloverTask(id: UUID(), status: .inbox, dueDate: "2026-10-01")
        let future = RolloverTask(id: UUID(), status: .scheduled, scheduledDate: "2026-10-13", orderIndex: 1024)
        #expect(Rollover.apply(to: [done, inbox, future], today: today).isEmpty)
    }

    @Test("Idempotent : un second appel ne reporte rien")
    func idempotent() {
        let task = RolloverTask(id: UUID(), status: .scheduled, scheduledDate: "2026-10-11", orderIndex: 1024)
        let first = Rollover.apply(to: [task], today: today)
        #expect(Rollover.apply(to: first, today: today).isEmpty)
    }
}

@Suite("Durées par défaut")
struct DurationTests {
    @Test func existingDurationWins() {
        #expect(Durations.defaultDuration(existing: 50, suggested: 15) == 50)
    }

    @Test func suggestionThenFallback() {
        #expect(Durations.defaultDuration(existing: nil, suggested: 90) == 90)
        #expect(Durations.defaultDuration(existing: nil, suggested: nil) == 30)
    }

    @Test func neverBelowMinimum() {
        #expect(Durations.defaultDuration(existing: 2, suggested: nil) == 5)
        #expect(Durations.defaultDuration(existing: nil, suggested: 1) == 5)
    }
}
