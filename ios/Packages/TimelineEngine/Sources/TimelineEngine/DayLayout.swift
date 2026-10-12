import Foundation

/// Position calculée d'un item dans la journée.
public struct Placement: Sendable, Hashable {
    public let id: UUID
    public let start: Minutes
    public let end: Minutes
    /// Temps libre entre la fin de l'item précédent (ou le début du jour) et ce début.
    public let gapBefore: Minutes
    /// Dernière ancre qui a repoussé cette flottante, `nil` si elle n'a pas été poussée.
    public let pushedPastAnchor: UUID?
    /// Ancre qui chevauche une autre ancre : signal discret, pas une erreur.
    public let overlapsAnchor: Bool
    public let isAnchored: Bool
}

public struct DayLayout: Sendable, Hashable {
    /// Placements dans l'ordre d'affichage, qui est aussi la séquence normalisée.
    public let placements: [Placement]
    /// Somme des minutes dont les flottantes ont été repoussées par des ancres.
    public let totalPushedMinutes: Minutes

    public var sequence: [UUID] { placements.map(\.id) }
    public var endOfDay: Minutes? { placements.map(\.end).max() }
}

extension TimelineEngine {
    /// Calcule les heures de début du jour (ADR-005, R1 à R3).
    ///
    /// R1 : une ancre ne bouge jamais. R2 : après une ancre, on repart de sa fin, trou autorisé.
    /// R3 : une flottante qui chevaucherait une ancre est poussée entière après elle.
    public static func layoutDay(dayStart: Minutes, items: [TimelineItem]) -> DayLayout {
        let sequence = preparedSequence(items)
        let anchors = sequence.filter(\.isAnchored)

        var cursor = dayStart
        var totalPushed = 0
        var raw: [(placement: Placement, position: Int)] = []

        for (position, item) in sequence.enumerated() {
            if let anchorStart = item.anchorStart {
                let end = anchorStart + item.durationMin
                let overlaps = anchors.contains { other in
                    other.id != item.id && intersects(other, start: anchorStart, end: end)
                }
                cursor = max(cursor, end)
                raw.append((Placement(id: item.id, start: anchorStart, end: end, gapBefore: 0,
                                      pushedPastAnchor: nil, overlapsAnchor: overlaps, isAnchored: true),
                            position))
            } else {
                var start = cursor
                var pushedBy: UUID?
                while let blocking = anchors
                    .filter({ intersects($0, start: start, end: start + item.durationMin) })
                    .max(by: { anchorEnd($0) < anchorEnd($1) }) {
                    start = anchorEnd(blocking)
                    pushedBy = blocking.id
                }
                totalPushed += start - cursor
                cursor = start + item.durationMin
                raw.append((Placement(id: item.id, start: start, end: cursor, gapBefore: 0,
                                      pushedPastAnchor: pushedBy, overlapsAnchor: false, isAnchored: false),
                            position))
            }
        }

        let ordered = raw.sorted { ($0.placement.start, $0.position) < ($1.placement.start, $1.position) }
        var previousEnd = dayStart
        let placements = ordered.map { entry in
            let p = entry.placement
            let gap = max(0, p.start - previousEnd)
            previousEnd = max(previousEnd, p.end)
            return Placement(id: p.id, start: p.start, end: p.end, gapBefore: gap,
                             pushedPastAnchor: p.pushedPastAnchor, overlapsAnchor: p.overlapsAnchor,
                             isAnchored: p.isAnchored)
        }
        return DayLayout(placements: placements, totalPushedMinutes: totalPushed)
    }

    /// Séquence stockée (tri par `orderIndex`), puis ancres remises dans l'ordre de leur heure
    /// sur les places qu'elles occupent, sans toucher aux positions relatives des flottantes.
    static func preparedSequence(_ items: [TimelineItem]) -> [TimelineItem] {
        var sequence = storedOrder(items)
        let anchorSlots = sequence.indices.filter { sequence[$0].isAnchored }
        let sortedAnchors = anchorSlots.map { sequence[$0] }.sorted {
            ($0.anchorStart!, $0.orderIndex, $0.id.uuidString) < ($1.anchorStart!, $1.orderIndex, $1.id.uuidString)
        }
        for (slot, anchor) in zip(anchorSlots, sortedAnchors) {
            sequence[slot] = anchor
        }
        return sequence
    }

    static func storedOrder(_ items: [TimelineItem]) -> [TimelineItem] {
        items.sorted { ($0.orderIndex, $0.id.uuidString) < ($1.orderIndex, $1.id.uuidString) }
    }

    private static func anchorEnd(_ anchor: TimelineItem) -> Minutes {
        anchor.anchorStart! + anchor.durationMin
    }

    private static func intersects(_ anchor: TimelineItem, start: Minutes, end: Minutes) -> Bool {
        anchor.anchorStart! < end && anchorEnd(anchor) > start
    }
}
