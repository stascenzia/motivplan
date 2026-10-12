import Foundation
import Testing
@testable import TimelineEngine

@Suite("Séquence : indices à trous, normalisation, ancres, déplacements")
struct SequencingTests {
    @Test func reindexMovesASingleItem() {
        let ids = (0..<4).map { _ in UUID() }
        let current = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, ($0 + 1) * 1024) })
        // Déplacer le dernier en deuxième position : une seule écriture.
        let target = [ids[0], ids[3], ids[1], ids[2]]
        let changes = OrderIndex.reindex(target: target, current: current)
        #expect(changes.count == 1)
        #expect(changes[ids[3]] == 1536)
    }

    @Test func reindexRenumbersWhenGapIsExhausted() {
        let ids = (0..<3).map { _ in UUID() }
        let current = [ids[0]: 10, ids[1]: 11, ids[2]: 12]
        // ids[0] doit se glisser entre 11 et 12 : plus de place, tout est renuméroté.
        let target = [ids[1], ids[0], ids[2]]
        let changes = OrderIndex.reindex(target: target, current: current)
        let final = current.merging(changes) { $1 }
        #expect(target.map { final[$0]! } == [1024, 2048, 3072])
    }

    @Test func reindexPlacesNewItemsAtTheEdges() {
        let a = UUID(), b = UUID(), fresh = UUID()
        let first = OrderIndex.reindex(target: [fresh, a, b], current: [a: 1024, b: 2048])
        #expect(first == [fresh: 0])
        let last = OrderIndex.reindex(target: [a, b, fresh], current: [a: 1024, b: 2048])
        #expect(last == [fresh: 3072])
    }

    @Test("Normaliser T2 aligne la séquence stockée sur l'affichage")
    func normalizePushedFloat() {
        var day = Day([.float("A", 90), .anchor("M", "10:00", 60), .float("B", 30)])
        let changes = Sequencing.normalize(items: day.items, dayStart: TimelineEngine.defaultDayStart)
        #expect(changes.count == 1)
        day.apply(changes)
        #expect(TimelineEngine.storedOrder(day.items).map { day.name(of: $0.id) } == ["M", "A", "B"])
        #expect(Sequencing.normalize(items: day.items, dayStart: TimelineEngine.defaultDayStart).isEmpty)
        #expect(day.starts() == ["M": "10:00", "A": "11:00", "B": "12:30"])
    }

    @Test func normalizeIsEmptyWhenAlreadyNormal() {
        let day = Day([.float("A", 30), .anchor("M", "14:00", 60), .float("B", 30)])
        #expect(Sequencing.normalize(items: day.items, dayStart: TimelineEngine.defaultDayStart).isEmpty)
    }

    @Test("Poser une ancre la range par son heure et pousse ce qui déborde")
    func slotAnchor() {
        var day = Day([.float("A", 60), .float("B", 60), .float("C", 60)])
        let meeting = UUID()
        let changes = Sequencing.slotAnchor(id: meeting, anchorStart: hm("10:30"), durationMin: 60,
                                            into: day.items, dayStart: TimelineEngine.defaultDayStart)
        #expect(changes[meeting] != nil)
        day.items.append(TimelineItem(id: meeting, orderIndex: changes[meeting]!, durationMin: 60,
                                      anchorStart: hm("10:30")))
        day.apply(changes)

        let layout = day.layout()
        let stored = TimelineEngine.storedOrder(day.items).map(\.id)
        #expect(stored == layout.sequence)
        let byId = Dictionary(uniqueKeysWithValues: layout.placements.map { ($0.id, clock($0.start)) })
        // A 09:00, B débordait sur 10:30 → poussée à 11:30, C suit.
        #expect(byId[day.ids["A"]!] == "09:00")
        #expect(byId[meeting] == "10:30")
        #expect(byId[day.ids["B"]!] == "11:30")
        #expect(byId[day.ids["C"]!] == "12:30")
    }

    @Test func moveFloatWritesOneIndex() {
        var day = Day([.float("A", 30), .float("B", 30), .float("C", 30)])
        let changes = Sequencing.move(id: day.ids["C"]!, to: 0, in: day.items,
                                      dayStart: TimelineEngine.defaultDayStart)
        #expect(changes.count == 1)
        day.apply(changes)
        #expect(day.sequence() == ["C", "A", "B"])
    }

    @Test func moveIgnoresAnchors() {
        let day = Day([.float("A", 30), .anchor("M", "14:00", 60)])
        #expect(Sequencing.move(id: day.ids["M"]!, to: 0, in: day.items,
                                dayStart: TimelineEngine.defaultDayStart).isEmpty)
    }

    @Test func moveBeforeAnchorThatOverflowsIsPushedBack() {
        // Placer une tâche de 3 h juste avant une ancre à 10:00 : elle est poussée après l'ancre.
        var day = Day([.anchor("M", "10:00", 60), .float("A", 30), .float("Long", 180)])
        let changes = Sequencing.move(id: day.ids["Long"]!, to: 0, in: day.items,
                                      dayStart: TimelineEngine.defaultDayStart)
        day.apply(changes)
        #expect(day.sequence() == ["M", "Long", "A"])
        #expect(TimelineEngine.storedOrder(day.items).map(\.id) == day.layout().sequence)
    }

    @Test func appendFloatGoesLast() {
        var day = Day([.float("A", 30), .anchor("M", "14:00", 60)])
        let fresh = TimelineItem(id: UUID(), orderIndex: 0, durationMin: 30)
        let changes = Sequencing.append(fresh, to: day.items, dayStart: TimelineEngine.defaultDayStart)
        day.items.append(TimelineItem(id: fresh.id, orderIndex: changes[fresh.id]!, durationMin: 30))
        day.apply(changes)
        #expect(day.layout().sequence.last == fresh.id)
        #expect(day.layout().placements.last?.start == hm("15:00"))
    }
}
