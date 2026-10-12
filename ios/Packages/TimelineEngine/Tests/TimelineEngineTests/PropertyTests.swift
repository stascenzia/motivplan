import Foundation
import Testing
@testable import TimelineEngine

/// Invariants I1–I5 du plan, vérifiés sur des journées générées aléatoirement (graines fixes).
@Suite("Invariants du moteur sur journées aléatoires")
struct PropertyTests {
    static let seeds: [UInt64] = Array(1...400)

    static func randomDay(seed: UInt64) -> (items: [TimelineItem], dayStart: Minutes) {
        var rng = SeededGenerator(seed: seed)
        let count = Int.random(in: 0...9, using: &rng)
        let indices = (0..<count).map { ($0 + 1) * 1024 }.shuffled(using: &rng)
        let items = (0..<count).map { position -> TimelineItem in
            let duration = 5 * Int.random(in: 1...36, using: &rng)
            let anchored = Int.random(in: 0..<3, using: &rng) == 0
            let anchorStart = anchored ? 5 * Int.random(in: (6 * 12)...(20 * 12), using: &rng) : nil
            return TimelineItem(id: UUID(), orderIndex: indices[position], durationMin: duration,
                                anchorStart: anchorStart)
        }
        let dayStart = 5 * Int.random(in: (7 * 12)...(10 * 12), using: &rng)
        return (items, dayStart)
    }

    @Test("I1 une ancre démarre à son heure", arguments: seeds)
    func anchorsNeverMove(seed: UInt64) {
        let (items, dayStart) = Self.randomDay(seed: seed)
        let layout = TimelineEngine.layoutDay(dayStart: dayStart, items: items)
        for item in items where item.isAnchored {
            #expect(layout.placements.first { $0.id == item.id }?.start == item.anchorStart)
        }
    }

    @Test("I2 aucune flottante ne chevauche une ancre", arguments: seeds)
    func floatsNeverOverlapAnchors(seed: UInt64) {
        let (items, dayStart) = Self.randomDay(seed: seed)
        let placements = TimelineEngine.layoutDay(dayStart: dayStart, items: items).placements
        for float in placements where !float.isAnchored {
            for anchor in placements where anchor.isAnchored {
                #expect(!(anchor.start < float.end && anchor.end > float.start))
            }
        }
    }

    @Test("I3 l'ordre relatif des flottantes est conservé", arguments: seeds)
    func floatOrderPreserved(seed: UInt64) {
        let (items, dayStart) = Self.randomDay(seed: seed)
        let stored = TimelineEngine.storedOrder(items).filter { !$0.isAnchored }.map(\.id)
        let floats = Set(stored)
        let displayed = TimelineEngine.layoutDay(dayStart: dayStart, items: items).sequence.filter(floats.contains)
        #expect(displayed == stored)
    }

    @Test("I4 une flottante démarre après le début du jour et après l'item précédent", arguments: seeds)
    func floatsStartAfterPrevious(seed: UInt64) {
        let (items, dayStart) = Self.randomDay(seed: seed)
        let placements = TimelineEngine.layoutDay(dayStart: dayStart, items: items).placements
        for (index, placement) in placements.enumerated() where !placement.isAnchored {
            #expect(placement.start >= dayStart)
            if index > 0 {
                #expect(placement.start >= placements[index - 1].end)
            }
        }
    }

    @Test("I5 normaliser est idempotent et ne change pas l'affichage", arguments: seeds)
    func normalizationIsIdempotent(seed: UInt64) {
        let (items, dayStart) = Self.randomDay(seed: seed)
        let before = TimelineEngine.layoutDay(dayStart: dayStart, items: items)
        let changes = Sequencing.normalize(items: items, dayStart: dayStart)
        let normalized = items.map { item -> TimelineItem in
            var copy = item
            copy.orderIndex = changes[item.id] ?? item.orderIndex
            return copy
        }
        let after = TimelineEngine.layoutDay(dayStart: dayStart, items: normalized)

        #expect(TimelineEngine.storedOrder(normalized).map(\.id) == after.sequence)
        #expect(Sequencing.normalize(items: normalized, dayStart: dayStart).isEmpty)
        #expect(after.placements.map { [$0.start, $0.end] } == before.placements.map { [$0.start, $0.end] })
    }

    @Test("Déplacer une flottante garde séquence stockée = affichée", arguments: seeds)
    func moveKeepsSequenceNormalized(seed: UInt64) {
        let (items, dayStart) = Self.randomDay(seed: seed)
        var rng = SeededGenerator(seed: seed &+ 1_000)
        guard let float = items.filter({ !$0.isAnchored }).randomElement(using: &rng) else { return }
        let changes = Sequencing.move(id: float.id, to: Int.random(in: 0...items.count, using: &rng),
                                      in: items, dayStart: dayStart)
        let moved = items.map { item -> TimelineItem in
            var copy = item
            copy.orderIndex = changes[item.id] ?? item.orderIndex
            return copy
        }
        #expect(Set(moved.map(\.orderIndex)).count == moved.count)
        #expect(TimelineEngine.storedOrder(moved).map(\.id)
                == TimelineEngine.layoutDay(dayStart: dayStart, items: moved).sequence)
    }
}
