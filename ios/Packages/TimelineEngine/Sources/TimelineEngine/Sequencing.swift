import Foundation

/// Opérations sur la séquence d'un jour. Chacune renvoie les `orderIndex` à écrire,
/// déjà normalisés : séquence stockée = séquence affichée (ADR-005).
public enum Sequencing {
    /// Si des flottantes ont été poussées après une ancre, ou si des ancres sont stockées
    /// dans le désordre, renvoie les indices qui alignent la séquence stockée sur l'affichage.
    /// Vide si la séquence est déjà normalisée (idempotent).
    public static func normalize(items: [TimelineItem], dayStart: Minutes) -> [UUID: Int] {
        let displayed = TimelineEngine.layoutDay(dayStart: dayStart, items: items).sequence
        let stored = TimelineEngine.storedOrder(items).map(\.id)
        guard displayed != stored else { return [:] }
        return OrderIndex.reindex(target: displayed, current: currentIndices(items))
    }

    /// Place une ancre (nouvelle ou dont l'heure change) avant le premier item qui démarre
    /// à son heure ou après, puis normalise.
    public static func slotAnchor(id: UUID, anchorStart: Minutes, durationMin: Minutes,
                                  into items: [TimelineItem], dayStart: Minutes) -> [UUID: Int] {
        let others = items.filter { $0.id != id }
        let layout = TimelineEngine.layoutDay(dayStart: dayStart, items: others)
        var target = layout.sequence
        let insertAt = layout.placements.firstIndex { $0.start >= anchorStart } ?? target.count
        target.insert(id, at: insertAt)

        let anchor = TimelineItem(id: id, orderIndex: 0, durationMin: durationMin, anchorStart: anchorStart)
        return applyThenNormalize(target: target, items: others + [anchor], dayStart: dayStart,
                                  current: currentIndices(others))
    }

    /// Déplace une flottante à la position `position` de la séquence affichée, puis normalise.
    /// Une ancre ne se déplace pas : on change son heure (`slotAnchor`).
    public static func move(id: UUID, to position: Int, in items: [TimelineItem],
                            dayStart: Minutes) -> [UUID: Int] {
        guard let item = items.first(where: { $0.id == id }), !item.isAnchored else { return [:] }
        var target = TimelineEngine.layoutDay(dayStart: dayStart, items: items).sequence
        target.removeAll { $0 == id }
        target.insert(id, at: min(max(position, 0), target.count))
        return applyThenNormalize(target: target, items: items, dayStart: dayStart,
                                  current: currentIndices(items))
    }

    /// Ajoute une flottante (ou une ancre) en fin de séquence, puis normalise.
    public static func append(_ item: TimelineItem, to items: [TimelineItem], dayStart: Minutes) -> [UUID: Int] {
        if let anchorStart = item.anchorStart {
            return slotAnchor(id: item.id, anchorStart: anchorStart, durationMin: item.durationMin,
                              into: items, dayStart: dayStart)
        }
        let others = items.filter { $0.id != item.id }
        var placed = item
        placed.orderIndex = OrderIndex.appended(after: others.map(\.orderIndex))
        let normalization = normalize(items: others + [placed], dayStart: dayStart)
        return normalization.merging([item.id: placed.orderIndex]) { normalized, _ in normalized }
    }

    private static func applyThenNormalize(target: [UUID], items: [TimelineItem], dayStart: Minutes,
                                           current: [UUID: Int]) -> [UUID: Int] {
        let reordered = OrderIndex.reindex(target: target, current: current)
        let updated = items.map { item -> TimelineItem in
            var copy = item
            copy.orderIndex = reordered[item.id] ?? current[item.id] ?? item.orderIndex
            return copy
        }
        let normalization = normalize(items: updated, dayStart: dayStart)
        var result = reordered.merging(normalization) { _, normalized in normalized }
        // Ne renvoyer que les vrais changements par rapport à l'état stocké.
        result = result.filter { current[$0.key] != $0.value }
        return result
    }

    private static func currentIndices(_ items: [TimelineItem]) -> [UUID: Int] {
        Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.orderIndex) })
    }
}
